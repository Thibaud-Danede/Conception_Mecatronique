// ============================================================================
// Couche de communication entre le sketch Processing et RobotPoseBridge.exe.
//
// Architecture:
// - Processing lance un bridge C# local (RobotPoseBridge.exe)
// - Processing ecrit les ordres dans robot_command.csv
// - Le bridge lit ces ordres, parle au SDK xArm, puis reecrit l'etat courant
//   et les diagnostics dans robot_pose.csv
// - Processing reparce ensuite robot_pose.csv pour alimenter toute l'IHM
//
// Chaines d'appel importantes:
// - setupRobotBridge()
//   -> resetRobotPoseFile()
//   -> resetRobotCommandFile()
//   -> clearBridgeRuntimeState()
//   -> setupLocalRobotBridge()
//   -> loadRobotPoseFromBridge()
//
// - draw() appelle updateRobotBridge()
//   -> requestRobotPoseRefresh() si le CSV a change
//   -> loadRobotPoseFromBridge() pour parser l'etat
//
// - sendRobotJointCommand()/sendRobotCartesian...()/sendRobotToolVelocity...
//   -> sendRobotCommand()
//   -> queueRobotCommandFileWrite()
//   -> flushRobotCommandWrites()
//   -> writeBridgeTextFileNow()
// ============================================================================

// Etat de telemetrie expose a l'IHM.
boolean hasRobotConnection = false;
boolean hasLiveRobotPose = false;
String liveRobotIp = "unknown";
String liveTimestamp = "";
String liveRobotStatus = "disconnected";
String liveRobotModeStatus = "real unavailable";
String liveSafetyStatus = "self collision unavailable";
String liveDiagnosticStatus = "diagnostic pending";
String liveDiagnosticNetwork = "web port check pending";
String liveDiagnosticSdk = "SDK check pending";
String robotPosePath = "";
String robotCommandPath = "";

// Etat derive du bridge sur la partie "robot reel pret a bouger".
boolean bridgeRealReady = false;
boolean bridgeSafetyReady = false;
boolean bridgeValidationPassed = false;
int bridgeReportedCommandSequence = 0;
String bridgeReportedCommandMode = "none";
String bridgeValidationStatus = "not validated";

// Caches des positions live et de la derniere validation IK.
float[] liveJoints = {0, 0, 0, 0, 0, 0};
float[] liveCartesian = {0, 0, 0, 0, 0, 0};
float[] bridgeValidationTarget = {0, 0, 0, 0, 0, 0};
float[] bridgeValidationJoints = {0, 0, 0, 0, 0, 0};

// Cadence de polling cote Processing.
int robotPollIntervalMs = 200;
int lastRobotPollMs = -1000;
int lastRobotUpdateMs = -1;

// Processus bridge local et etat de lancement.
Process robotBridgeProcess = null;
String bridgeLaunchStatus = "not started";
String bridgeExePath = "";
String bridgeLogPath = "";
String bridgeCommandStatus = "idle";
int bridgeCommandSequence = 0;
boolean bridgeReconnectInProgress = false;
int bridgeReconnectStartMs = -1;

// Petits verrous/caches pour limiter les collisions lecture/ecriture sur les fichiers CSV.
Object robotPoseIoLock = new Object();
Object robotCommandIoLock = new Object();
volatile boolean robotPoseReadInProgress = false;
volatile long robotPoseCachedModifiedMs = -1;
volatile String[] robotPoseCachedLines = null;
volatile boolean robotCommandWriteInProgress = false;
volatile String[] robotCommandPendingLines = null;
volatile String robotCommandIoStatus = "idle";
volatile int robotCommandWriteGeneration = 0;
volatile int robotCommandPendingGeneration = 0;

// Point d'entree du sous-systeme de communication robot.
void setupRobotBridge() {
  robotPosePath = sketchPath("robot_pose.csv");
  robotCommandPath = sketchPath(bridgeCommandFileName);
  bridgeLogPath = bridgeDiagnosticLogEnabled ? sketchPath("bridge_launch.log") : "";
  // On recree d'abord des fichiers CSV coherents pour que le sketch et le
  // bridge puissent demarrer meme s'il n'existe encore aucune telemetrie.
  resetRobotPoseFile();
  resetRobotCommandFile();
  clearBridgeRuntimeState();
  setupLocalRobotBridge();
  // Lecture immediate d'un premier etat, utile si un bridge tourne deja.
  loadRobotPoseFromBridge();
}

// Prepare le chemin du bridge et l'enregistrement du hook de fermeture.
void setupLocalRobotBridge() {
  bridgeExePath = sketchPath(bridgeExecutableRelativePath);
  robotPollIntervalMs = bridgeLaunchPollMs;
  registerMethod("dispose", this);
  cleanupStaleRobotBridgeProcessesIfNeeded();

  if (bridgeAutoStartEnabled) {
    startRobotBridgeProcess();
  } else {
    bridgeLaunchStatus = "autostart disabled";
  }
}

// Lance le bridge C# en processus local avec son dossier de travail et, si besoin, un log.
void startRobotBridgeProcess() {
  if (robotBridgeProcess != null && robotBridgeProcess.isAlive()) {
    bridgeLaunchStatus = "bridge already running";
    return;
  }

  File bridgeExe = new File(bridgeExePath);
  if (!bridgeExe.exists()) {
    bridgeLaunchStatus = "bridge exe missing";
    appendBridgeLogLine("bridge exe missing: " + bridgeExePath);
    bridgeReconnectInProgress = false;
    return;
  }

  try {
    File bridgeWorkingDirectory = bridgeExe.getParentFile();
    if (bridgeWorkingDirectory == null || !bridgeWorkingDirectory.exists()) {
      bridgeWorkingDirectory = new File(sketchPath(""));
    }

    String[] command = {
      bridgeExePath,
      "--ip", bridgeTargetIp,
      "--pose-file", robotPosePath,
      "--command-file", robotCommandPath,
      "--poll-ms", str(bridgeLaunchPollMs),
      "--motion-speed", str(bridgeMotionSpeed)
    };

    // Le bridge lit les commandes depuis un CSV et reecrit la telemetrie dans un autre.
    appendBridgeLogLine("starting bridge");
    appendBridgeLogLine("exe: " + bridgeExePath);
    appendBridgeLogLine("workdir: " + bridgeWorkingDirectory.getAbsolutePath());
    appendBridgeLogLine("target: " + bridgeTargetIp);
    appendBridgeLogLine("pose file: " + robotPosePath);
    appendBridgeLogLine("command file: " + robotCommandPath);

    ProcessBuilder builder = new ProcessBuilder(command);
    builder.directory(bridgeWorkingDirectory);
    builder.redirectErrorStream(true);
    if (bridgeLogPath.length() > 0) {
      builder.redirectOutput(ProcessBuilder.Redirect.appendTo(new File(bridgeLogPath)));
    }
    String currentPath = builder.environment().get("PATH");
    String binPath = bridgeWorkingDirectory.getAbsolutePath();
    // Ajoute le dossier du bridge au PATH pour que xarm.dll soit trouvable.
    if (currentPath == null || currentPath.length() == 0) {
      builder.environment().put("PATH", binPath);
    } else {
      builder.environment().put("PATH", binPath + File.pathSeparator + currentPath);
    }

    robotBridgeProcess = builder.start();
    // Petite pause defensive: si le process meurt instantanement, on remonte
    // tout de suite un statut utile plutot qu'un "running" trompeur.
    delay(120);
    if (!robotBridgeProcess.isAlive()) {
      int exitCode = robotBridgeProcess.exitValue();
      bridgeLaunchStatus = "bridge exited (" + exitCode + ")";
      appendBridgeLogLine("bridge exited quickly with code " + exitCode);
      bridgeReconnectInProgress = false;
      return;
    }

    bridgeLaunchStatus = bridgeReconnectInProgress
      ? "bridge reconnect started"
      : "bridge started for " + bridgeTargetIp;
    appendBridgeLogLine("bridge started");
  } catch (Exception ex) {
    bridgeLaunchStatus = "bridge start failed: " + ex.getMessage();
    appendBridgeLogLine("bridge start failed: " + ex.getClass().getSimpleName() + ": " + ex.getMessage());
    bridgeReconnectInProgress = false;
  }
}

// Hook appele a la fermeture du sketch Processing.
public void dispose() {
  closeForceSensorPort();
  stopRobotBridgeProcess();
  cleanupStaleRobotBridgeProcessesIfNeeded();
}

// Arrete le bridge local en essayant d'abord un shutdown propre.
void stopRobotBridgeProcess() {
  if (robotBridgeProcess != null) {
    try {
      if (robotBridgeProcess.isAlive()) {
        robotBridgeProcess.destroy();
        waitForProcessExit(robotBridgeProcess, 500);
        if (robotBridgeProcess.isAlive()) {
          robotBridgeProcess.destroyForcibly();
          waitForProcessExit(robotBridgeProcess, 500);
        }
      }
    } catch (Exception ex) {
      bridgeLaunchStatus = "bridge stop failed: " + ex.getMessage();
    }
  }

  robotBridgeProcess = null;
  if (!bridgeReconnectInProgress) {
    bridgeLaunchStatus = "bridge stopped";
  }
}

// Reinitialise l'etat local puis relance le bridge.
void requestRobotBridgeReconnect() {
  if (bridgeReconnectInProgress) {
    return;
  }

  // La reconnexion repart completement a zero:
  // process bridge stoppe -> fichiers CSV reinitialises -> caches invalides -> relance.
  bridgeReconnectInProgress = true;
  bridgeReconnectStartMs = millis();
  bridgeLaunchStatus = "reconnecting...";
  stopRobotBridgeProcess();
  resetRobotPoseFile();
  resetRobotCommandFile();
  clearBridgeRuntimeState();
  clearMgiValidationCache("Reconnect requested. Validate again before sending.");
  startRobotBridgeProcess();
}

// Repart d'un fichier commande neutre pour que le bridge lise un etat coherent.
void resetRobotCommandFile() {
  // On republie une commande "none" de sequence 0 pour que le bridge lise
  // un etat neutre coherent meme juste apres un restart.
  bridgeCommandStatus = "idle";
  bridgeCommandSequence = 0;
  bridgeReportedCommandMode = "none";
  bridgeReportedCommandSequence = 0;
  synchronized (robotCommandIoLock) {
    robotCommandWriteGeneration++;
    robotCommandPendingLines = null;
    robotCommandPendingGeneration = robotCommandWriteGeneration;
  }
  if (robotCommandPath.length() > 0) {
    String[] lines = {
      "sequence,0",
      "timestamp," + buildRobotBridgeTimestamp(),
      "mode,none",
      "values,0,0,0,0,0,0"
    };
    writeBridgeTextFileNow(robotCommandPath, lines);
  }
}

// Repart d'un fichier telemetrie vide mais syntaxiquement valide.
void resetRobotPoseFile() {
  // Meme si aucun bridge n'a encore tourne, on veut un CSV syntaxiquement valide
  // pour que l'IHM puisse afficher un etat initial lisible.
  hasRobotConnection = false;
  hasLiveRobotPose = false;
  liveRobotStatus = "waiting for bridge";
  liveRobotModeStatus = "real unavailable";
  liveSafetyStatus = "self collision unavailable";
  liveDiagnosticStatus = "diagnostic pending";
  liveDiagnosticNetwork = "web port check pending";
  liveDiagnosticSdk = "SDK check pending";
  lastRobotUpdateMs = -1;
  robotPoseCachedModifiedMs = -1;
  robotPoseCachedLines = null;
  zeroFloatArray(liveJoints);
  zeroFloatArray(liveCartesian);
  if (robotPosePath.length() > 0) {
    String[] lines = {
      "connected,0",
      "timestamp," + buildRobotBridgeTimestamp(),
      "ip," + bridgeTargetIp,
      "real_ready,0",
      "safety_ready,0",
      "joints,0,0,0,0,0,0",
      "cartesian,0,0,0,0,0,0",
      "robot_status," + liveRobotStatus,
      "robot_mode_status," + liveRobotModeStatus,
      "safety_status," + liveSafetyStatus,
      "diagnostic_status," + liveDiagnosticStatus,
      "diagnostic_network," + liveDiagnosticNetwork,
      "diagnostic_sdk," + liveDiagnosticSdk,
      "command_mode,none",
      "command_sequence,0",
      "command_status,idle",
      "validation_valid,0",
      "validation_status,not validated",
      "validation_target,0,0,0,0,0,0",
      "validation_joints,0,0,0,0,0,0"
    };
    writeBridgeTextFileNow(robotPosePath, lines);
  }
}

// Oublie les validations et flags derives du bridge precedent.
void clearBridgeRuntimeState() {
  bridgeRealReady = false;
  bridgeSafetyReady = false;
  bridgeValidationPassed = false;
  bridgeValidationStatus = "not validated";
  zeroFloatArray(bridgeValidationTarget);
  zeroFloatArray(bridgeValidationJoints);
}

// Polling principal du bridge cote Processing.
void updateRobotBridge() {
  if (millis() - lastRobotPollMs < robotPollIntervalMs) {
    // Meme sans nouveau poll CSV, on continue a surveiller l'etat de reconnect.
    updateReconnectState();
    return;
  }

  lastRobotPollMs = millis();
  loadRobotPoseFromBridge();
  updateReconnectState();
}

// Gere les timeouts de reconnexion vus par l'IHM.
void updateReconnectState() {
  if (!bridgeReconnectInProgress) {
    return;
  }

  if (robotBridgeProcess == null || !robotBridgeProcess.isAlive()) {
    if (millis() - bridgeReconnectStartMs > 1200) {
      bridgeReconnectInProgress = false;
      bridgeLaunchStatus = "reconnect failed";
    }
    return;
  }

  if (millis() - bridgeReconnectStartMs > 5000) {
    bridgeReconnectInProgress = false;
    bridgeLaunchStatus = "reconnect timeout";
  }
}

// Lit le CSV de telemetrie produit par le bridge et le convertit en etat UI.
void loadRobotPoseFromBridge() {
  File poseFile = new File(robotPosePath);
  if (!poseFile.exists()) {
    hasRobotConnection = false;
    hasLiveRobotPose = false;
    liveRobotStatus = "no bridge data";
    return;
  }

  requestRobotPoseRefresh(poseFile);

  String[] lines = robotPoseCachedLines;
  if (lines == null || lines.length == 0) {
    if (!robotPoseReadInProgress) {
      hasRobotConnection = false;
      hasLiveRobotPose = false;
      liveRobotStatus = "empty bridge data";
    }
    return;
  }

  // Variables temporaires pour ne basculer l'etat global qu'une fois le parse termine.
  // Cela evite de melanger un ancien etat avec un nouveau parse partiel.
  boolean parsedConnected = false;
  boolean parsedRealReady = false;
  boolean parsedSafetyReady = false;
  String parsedIp = liveRobotIp;
  String parsedTimestamp = liveTimestamp;
  String parsedRobotStatus = liveRobotStatus;
  String parsedRobotModeStatus = liveRobotModeStatus;
  String parsedSafetyStatus = liveSafetyStatus;
  String parsedDiagnosticStatus = liveDiagnosticStatus;
  String parsedDiagnosticNetwork = liveDiagnosticNetwork;
  String parsedDiagnosticSdk = liveDiagnosticSdk;
  float[] parsedJoints = {0, 0, 0, 0, 0, 0};
  float[] parsedCartesian = {0, 0, 0, 0, 0, 0};
  int parsedCommandSequence = bridgeReportedCommandSequence;
  String parsedCommandMode = bridgeReportedCommandMode;
  String parsedCommandStatus = bridgeCommandStatus;
  boolean parsedValidationPassed = bridgeValidationPassed;
  String parsedValidationStatus = bridgeValidationStatus;
  float[] parsedValidationTarget = bridgeValidationTarget.clone();
  float[] parsedValidationJoints = bridgeValidationJoints.clone();

  for (String rawLine : lines) {
    String cleanLine = trim(rawLine);
    if (cleanLine.length() == 0) {
      continue;
    }

    String[] parts = split(cleanLine, ',');
    if (parts.length < 2) {
      continue;
    }

    String key = trim(parts[0]);
    // Le contrat ici est simple: chaque cle du CSV bridge ecrase une partie
    // precise de l'etat local Processing.
    if (key.equals("connected")) {
      parsedConnected = trim(parts[1]).equals("1");
    } else if (key.equals("real_ready")) {
      parsedRealReady = trim(parts[1]).equals("1");
    } else if (key.equals("safety_ready")) {
      parsedSafetyReady = trim(parts[1]).equals("1");
    } else if (key.equals("ip")) {
      parsedIp = join(subset(parts, 1), ",");
    } else if (key.equals("timestamp")) {
      parsedTimestamp = join(subset(parts, 1), ",");
    } else if (key.equals("robot_status")) {
      parsedRobotStatus = join(subset(parts, 1), ",");
    } else if (key.equals("robot_mode_status")) {
      parsedRobotModeStatus = join(subset(parts, 1), ",");
    } else if (key.equals("safety_status")) {
      parsedSafetyStatus = join(subset(parts, 1), ",");
    } else if (key.equals("diagnostic_status")) {
      parsedDiagnosticStatus = join(subset(parts, 1), ",");
    } else if (key.equals("diagnostic_network")) {
      parsedDiagnosticNetwork = join(subset(parts, 1), ",");
    } else if (key.equals("diagnostic_sdk")) {
      parsedDiagnosticSdk = join(subset(parts, 1), ",");
    } else if (key.equals("joints")) {
      fillFloatArray(parsedJoints, parts, 1);
    } else if (key.equals("cartesian")) {
      fillFloatArray(parsedCartesian, parts, 1);
    } else if (key.equals("command_mode")) {
      parsedCommandMode = join(subset(parts, 1), ",");
    } else if (key.equals("command_sequence")) {
      parsedCommandSequence = int(parseFloatSafe(parts[1], parsedCommandSequence));
    } else if (key.equals("command_status")) {
      parsedCommandStatus = join(subset(parts, 1), ",");
    } else if (key.equals("validation_valid")) {
      parsedValidationPassed = trim(parts[1]).equals("1");
    } else if (key.equals("validation_status")) {
      parsedValidationStatus = join(subset(parts, 1), ",");
    } else if (key.equals("validation_target")) {
      fillFloatArray(parsedValidationTarget, parts, 1);
    } else if (key.equals("validation_joints")) {
      fillFloatArray(parsedValidationJoints, parts, 1);
    }
  }

  liveRobotIp = parsedIp;
  liveTimestamp = parsedTimestamp;
  liveRobotStatus = parsedRobotStatus;
  liveRobotModeStatus = parsedRobotModeStatus;
  liveSafetyStatus = parsedSafetyStatus;
  liveDiagnosticStatus = parsedDiagnosticStatus;
  liveDiagnosticNetwork = parsedDiagnosticNetwork;
  liveDiagnosticSdk = parsedDiagnosticSdk;
  bridgeReportedCommandSequence = parsedCommandSequence;
  bridgeReportedCommandMode = parsedCommandMode;
  bridgeCommandStatus = parsedCommandStatus;
  bridgeRealReady = parsedRealReady;
  bridgeSafetyReady = parsedSafetyReady;
  bridgeValidationPassed = parsedValidationPassed;
  bridgeValidationStatus = parsedValidationStatus;
  arrayCopy(parsedValidationTarget, bridgeValidationTarget);
  arrayCopy(parsedValidationJoints, bridgeValidationJoints);
  hasRobotConnection = parsedConnected;
  hasLiveRobotPose = parsedConnected && parsedRealReady;

  if (hasLiveRobotPose) {
    // Les valeurs live ne sont publiees globalement que si le bridge confirme
    // a la fois la connexion et le mode "real ready".
    arrayCopy(parsedJoints, liveJoints);
    arrayCopy(parsedCartesian, liveCartesian);
    lastRobotUpdateMs = millis();
    captureInitialMgiPoseFromRobotIfNeeded();
  } else {
    zeroFloatArray(liveJoints);
    zeroFloatArray(liveCartesian);
  }

  if (bridgeReconnectInProgress) {
    bridgeReconnectInProgress = false;
    bridgeLaunchStatus = parsedConnected ? "bridge running" : "bridge responding";
  }
}

// Remplit un tableau float depuis une ligne CSV "key,v1,v2,...".
void fillFloatArray(float[] target, String[] parts, int offset) {
  for (int i = 0; i < target.length; i++) {
    int sourceIndex = i + offset;
    if (sourceIndex < parts.length) {
      target[i] = parseFloatSafe(parts[sourceIndex], target[i]);
    }
  }
}

// Helper de remise a zero.
void zeroFloatArray(float[] values) {
  for (int i = 0; i < values.length; i++) {
    values[i] = 0;
  }
}

// Parse tolerant qui accepte la virgule comme separateur decimal.
float parseFloatSafe(String rawValue, float fallbackValue) {
  String normalized = trim(rawValue);
  normalized = normalized.replace(',', '.');
  float parsedValue = parseFloat(normalized);
  if (Float.isNaN(parsedValue)) {
    return fallbackValue;
  }

  return parsedValue;
}

// Commande articulaire brute pour le mode MGD.
void sendRobotJointCommand(float[] targetJoints) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "joint command blocked: " + getMotionBlockReason();
    return;
  }

  sendRobotCommand("joints", targetJoints);
}

// Demande de retour Home.
boolean sendRobotHomeCommand() {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "home command blocked: " + getMotionBlockReason();
    return false;
  }

  float[] neutralValues = {0, 0, 0, 0, 0, 0};
  sendRobotCommand("move_home", neutralValues);
  return true;
}

// Deplacement relatif outil, utile pour les interactions fines.
boolean sendRobotToolDeltaCommand(float[] deltaToolPose) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "tool delta blocked: " + getMotionBlockReason();
    return false;
  }

  sendRobotCommand("tool_delta", deltaToolPose);
  return true;
}

// Vitesse outil continue, utilisee notamment par le module force.
boolean sendRobotToolVelocityCommand(float[] toolVelocity) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "tool velocity blocked: " + getMotionBlockReason();
    return false;
  }

  sendRobotCommand("tool_velocity", toolVelocity);
  return true;
}

// Arret immediat cote bridge.
boolean sendRobotStopCommand() {
  if (!canQueueBridgeRequest()) {
    bridgeCommandStatus = "stop blocked: bridge unavailable";
    return false;
  }

  float[] neutralValues = {0, 0, 0, 0, 0, 0};
  sendRobotCommand("stop_motion", neutralValues);
  return true;
}

// Demande de validation IK sans execution de mouvement.
void sendRobotCartesianValidationCommand(float[] targetCartesian) {
  if (!canQueueBridgeRequest()) {
    bridgeCommandStatus = "validation blocked: bridge unavailable";
    return;
  }

  sendRobotCommand("cartesian_ik_validate", targetCartesian);
  bridgeValidationPassed = false;
  bridgeValidationStatus = "validation queued";
  arrayCopy(targetCartesian, bridgeValidationTarget);
}

// Execution d'une cible cartesienne deja validee.
boolean sendRobotCartesianExecuteCommand(float[] targetCartesian) {
  // L'execution MGI passe maintenant par le meme verrou de mouvement que les
  // autres ordres reels, y compris l'interlock de force latche.
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "execute blocked: " + getMotionBlockReason();
    return false;
  }

  if (!isCurrentMgiTargetValidated()) {
    bridgeCommandStatus = "execute blocked: validate the current target first";
    return false;
  }

  sendRobotCommand("cartesian_ik_execute", targetCartesian);
  return true;
}

// Ecrit une commande structurante dans le CSV lu par le bridge C#.
void sendRobotCommand(String mode, float[] values) {
  if (values == null || values.length < 6) {
    return;
  }

  // Le CSV commande est volontairement tres simple:
  // - sequence pour detecter les nouvelles requetes
  // - timestamp pour le debug
  // - mode pour choisir l'action cote bridge
  // - values pour les 6 floats de charge utile
  bridgeCommandSequence++;
  String[] lines = {
    "sequence," + bridgeCommandSequence,
    "timestamp," + year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "T" + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2),
    "mode," + mode,
    "values," + join(formatFloatArray(values), ",")
  };
  queueRobotCommandFileWrite(lines);
  // L'IHM anticipe le mode/numero envoye, puis attend que le bridge les
  // confirme plus tard dans robot_pose.csv.
  bridgeReportedCommandMode = mode;
  bridgeReportedCommandSequence = bridgeCommandSequence;
  bridgeCommandStatus = mode + " #" + bridgeCommandSequence + " queued";
}

// Le bridge doit etre en vie avant toute requete.
boolean canQueueBridgeRequest() {
  // Requete "bridge" = validation, stop ou mouvement, sans prejuger de la
  // disponibilite du vrai robot derriere.
  return !bridgeReconnectInProgress && robotBridgeProcess != null && robotBridgeProcess.isAlive();
}

// Un vrai mouvement demande en plus une telemetrie live exploitable.
boolean canQueueMotionCommand() {
  // Pour bouger reellement, on exige:
  // - bridge vivant
  // - robot connecte
  // - mode reel confirme
  // - securite bridge ok
  // - aucun interlock logiciel latche (par ex. safety stop force)
  return canQueueBridgeRequest() && !isForceSafetyStopLatched() && hasRobotConnection && bridgeRealReady && bridgeSafetyReady;
}

// Raison lisible pour l'operateur quand un mouvement est refuse.
String getMotionBlockReason() {
  // L'interlock de force est teste en premier pour faire remonter la vraie cause
  // du blocage au lieu d'un message plus generique sur le bridge ou le robot.
  if (isForceSafetyStopLatched()) {
    return getForceSafetyStopMotionBlockReason();
  }

  if (!canQueueBridgeRequest()) {
    return "bridge unavailable";
  }

  if (!hasRobotConnection) {
    return "robot disconnected";
  }

  if (!bridgeRealReady) {
    return "real robot mode not confirmed";
  }

  if (!bridgeSafetyReady) {
    return "self collision detection unavailable";
  }

  return "robot unavailable";
}

// Formatage CSV des tableaux de valeurs envoyes au bridge.
String[] formatFloatArray(float[] values) {
  String[] formatted = new String[values.length];
  for (int i = 0; i < values.length; i++) {
    formatted[i] = str(values[i]);
  }
  return formatted;
}

// Format horodatage simple reutilise dans les CSV et logs.
String buildRobotBridgeTimestamp() {
  return year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "T" + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
}

// Grande synthese d'etat visible dans le footer du sketch.
String buildFooterStatus() {
  String bridgeStatus = getBridgeRuntimeStatus();
  if (isForceSafetyStopLatched()) {
    // Tant qu'un safety stop est latche, le footer doit mettre cet etat au
    // premier plan plutot que les informations de pose ou de diagnostic.
    return "FORCE SAFETY STOP LATCHED | " + forceSafetyStopStatus + " | bridge: " + bridgeStatus;
  }

  String connectionLabel = hasRobotConnection ? "xArm CONNECTED" : "xArm DISCONNECTED";
  if (hasLiveRobotPose) {
    // Quand une pose live existe, on privilegie un resume "operateur" axe sur
    // la position et le dernier ordre plutot que sur les diagnostics bruts.
    int ageMs = max(0, millis() - lastRobotUpdateMs);
    return connectionLabel + " | " + liveRobotModeStatus + " | " + liveSafetyStatus + " | X: " + nf(liveCartesian[0], 1, 1) + " | Y: " + nf(liveCartesian[1], 1, 1) + " | Z: " + nf(liveCartesian[2], 1, 1) + " | " + bridgeCommandStatus + " | bridge: " + bridgeStatus + " | age: " + ageMs + " ms";
  }

  return connectionLabel + " | " + liveRobotStatus + " | diag: " + liveDiagnosticStatus + " | net: " + liveDiagnosticNetwork + " | sdk: " + liveDiagnosticSdk + " | bridge: " + bridgeStatus;
}

// Carte de telemetrie live affichee en bas a droite.
void drawLiveTelemetryCard() {
  float cardWidth = 340;
  float cardHeight = 172;
  float cardX = width - cardWidth - 20;
  float cardY = height - cardHeight - 55;
  String bridgeStatus = getBridgeRuntimeStatus();
  String ipLabel = hasRobotConnection ? liveRobotIp : bridgeTargetIp;
  color titleColor = hasLiveRobotPose
    ? color(0, 255, 150)
    : (hasRobotConnection ? color(255, 200, 90) : color(255, 120, 120));
  String title = hasLiveRobotPose
    ? "REAL ROBOT READY"
    : (hasRobotConnection ? "ROBOT CONNECTED - DEGRADED" : "ROBOT DISCONNECTED");

  noStroke();
  fill(32, 36, 44, 220);
  rect(cardX, cardY, cardWidth, cardHeight, 12);

  fill(titleColor);
  textAlign(LEFT, TOP);
  textSize(12);
  text(title, cardX + 14, cardY + 12);

  fill(220);
  textSize(11);
  text("IP: " + ipLabel, cardX + 14, cardY + 30);
  text("Robot: " + liveRobotStatus, cardX + 14, cardY + 46);
  text("Mode: " + liveRobotModeStatus, cardX + 14, cardY + 62);
  text("Safety: " + liveSafetyStatus, cardX + 14, cardY + 78);
  text("Diag: " + liveDiagnosticStatus, cardX + 14, cardY + 94);
  text("Net: " + liveDiagnosticNetwork, cardX + 14, cardY + 110);
  text("SDK: " + liveDiagnosticSdk, cardX + 14, cardY + 126);
  text("Bridge: " + bridgeStatus, cardX + 14, cardY + 142);
  text("CMD: " + bridgeCommandStatus, cardX + 14, cardY + 158);
  textAlign(LEFT, CENTER);
}

// Etat runtime simplifie du processus bridge.
String getBridgeRuntimeStatus() {
  if (bridgeReconnectInProgress) {
    return "reconnecting";
  }

  if (robotBridgeProcess == null) {
    return bridgeLaunchStatus;
  }

  if (robotBridgeProcess.isAlive()) {
    return "running";
  }

  return "stopped";
}

// Log optionnel du cycle de vie du bridge; ne doit jamais casser l'application.
void appendBridgeLogLine(String message) {
  if (bridgeLogPath.length() == 0) {
    return;
  }

  try {
    File logFile = new File(bridgeLogPath);
    File parentDir = logFile.getParentFile();
    if (parentDir != null && !parentDir.exists()) {
      parentDir.mkdirs();
    }
    java.util.List<String> line = java.util.Collections.singletonList(buildRobotBridgeTimestamp() + " | " + message);
    java.nio.file.Files.write(
      logFile.toPath(),
      line,
      java.nio.charset.StandardCharsets.UTF_8,
      java.nio.file.StandardOpenOption.CREATE,
      java.nio.file.StandardOpenOption.APPEND
    );
  } catch (Exception ex) {
    // Ignore logging errors to avoid blocking bridge startup.
  }
}

// Lecture defensive d'un fichier texte du bridge.
String[] loadStringsSafe(String path) {
  File file = new File(path);
  if (!file.exists()) {
    return new String[0];
  }

  String[] lines = readBridgeTextFile(path);
  if (lines == null) {
    return new String[0];
  }

  return lines;
}

// Nettoie les vieux RobotPoseBridge.exe qui pourraient bloquer le redemarrage.
void cleanupStaleRobotBridgeProcessesIfNeeded() {
  if (!bridgeKillStaleProcessesOnStart) {
    return;
  }

  String osName = System.getProperty("os.name", "").toLowerCase();
  if (!osName.contains("win")) {
    appendBridgeLogLine("stale bridge cleanup skipped on non-windows host");
    return;
  }

  try {
    ProcessBuilder killer = new ProcessBuilder("cmd", "/c", "taskkill /F /T /IM RobotPoseBridge.exe");
    killer.redirectErrorStream(true);
    Process killProcess = killer.start();
    killProcess.waitFor();
    waitForProcessExit(killProcess, max(100, bridgeStaleProcessKillWaitMs));
    appendBridgeLogLine("stale bridge cleanup exit code " + killProcess.exitValue());
  } catch (Exception ex) {
    appendBridgeLogLine("stale bridge cleanup failed: " + ex.getMessage());
  }
}

// Attente courte utilitaire pour laisser un process terminer.
void waitForProcessExit(Process process, int timeoutMs) {
  if (process == null) {
    return;
  }

  long waitUntilMs = System.currentTimeMillis() + max(0, timeoutMs);
  while (process.isAlive() && System.currentTimeMillis() < waitUntilMs) {
    try {
      Thread.sleep(20);
    } catch (Exception ex) {
      break;
    }
  }
}

// Declenche une lecture asynchrone si le CSV de pose a change.
void requestRobotPoseRefresh(File poseFile) {
  if (poseFile == null || !poseFile.exists()) {
    return;
  }

  long modifiedMs = poseFile.lastModified();
  if (modifiedMs <= 0) {
    return;
  }

  synchronized (robotPoseIoLock) {
    if (robotPoseReadInProgress || modifiedMs == robotPoseCachedModifiedMs) {
      return;
    }
    robotPoseReadInProgress = true;
  }

  final String posePathSnapshot = poseFile.getAbsolutePath();
  final long modifiedSnapshot = modifiedMs;
  Thread reader = new Thread(new Runnable() {
    public void run() {
      // Lecture dans un thread separe pour ne pas bloquer draw() sur le disque.
      String[] lines = readBridgeTextFile(posePathSnapshot);
      synchronized (robotPoseIoLock) {
        if (lines != null && lines.length > 0) {
          robotPoseCachedLines = lines;
          robotPoseCachedModifiedMs = modifiedSnapshot;
        }
        robotPoseReadInProgress = false;
      }
    }
  }, "RobotPoseReader");
  reader.setDaemon(true);
  reader.start();
}

// File d'ecriture "last write wins" pour les commandes robot.
void queueRobotCommandFileWrite(String[] lines) {
  if (robotCommandPath.length() == 0 || lines == null) {
    return;
  }

  synchronized (robotCommandIoLock) {
    // On garde seulement la derniere commande en attente: si plusieurs requetes
    // arrivent vite, la plus recente ecrase les anciennes non encore ecrites.
    robotCommandPendingLines = lines.clone();
    robotCommandPendingGeneration = robotCommandWriteGeneration;
    if (robotCommandWriteInProgress) {
      return;
    }
    robotCommandWriteInProgress = true;
  }

  final String commandPathSnapshot = robotCommandPath;
  Thread writer = new Thread(new Runnable() {
    public void run() {
      flushRobotCommandWrites(commandPathSnapshot);
    }
  }, "RobotCommandWriter");
  writer.setDaemon(true);
  writer.start();
}

// Vide la file des commandes en ecrivant toujours la plus recente.
void flushRobotCommandWrites(String targetPath) {
  while (true) {
    String[] linesToWrite = null;
    int writeGeneration = 0;

    synchronized (robotCommandIoLock) {
      if (robotCommandPendingLines != null) {
        linesToWrite = robotCommandPendingLines;
        writeGeneration = robotCommandPendingGeneration;
        robotCommandPendingLines = null;
      } else {
        robotCommandWriteInProgress = false;
        robotCommandIoStatus = "idle";
        return;
      }
    }

    if (writeGeneration != robotCommandWriteGeneration) {
      // Une reinitialisation de fichier a eu lieu entre temps; on ignore donc
      // cette ancienne ecriture devenue obsolescente.
      continue;
    }

    robotCommandIoStatus = writeBridgeTextFileNow(targetPath, linesToWrite)
      ? "write ok"
      : "write failed";
  }
}

// Ecriture atomique d'un fichier texte via un .tmp puis move.
boolean writeBridgeTextFileNow(String targetPath, String[] lines) {
  if (targetPath == null || targetPath.length() == 0 || lines == null) {
    return false;
  }

  try {
    File targetFile = new File(targetPath);
    File parentDir = targetFile.getParentFile();
    if (parentDir != null && !parentDir.exists()) {
      parentDir.mkdirs();
    }

    File tempFile = new File(targetPath + ".tmp");
    java.nio.file.Path tempPath = tempFile.toPath();
    java.nio.file.Path target = targetFile.toPath();
    java.util.List<String> fileLines = java.util.Arrays.asList(lines);

    java.nio.file.Files.write(tempPath, fileLines, java.nio.charset.StandardCharsets.UTF_8);

    try {
      // On prefere un move atomique pour eviter qu'un lecteur voie un fichier
      // partiellement ecrit; fallback non atomique si le FS ne le permet pas.
      java.nio.file.Files.move(
        tempPath,
        target,
        java.nio.file.StandardCopyOption.REPLACE_EXISTING,
        java.nio.file.StandardCopyOption.ATOMIC_MOVE
      );
    } catch (Exception moveEx) {
      java.nio.file.Files.move(
        tempPath,
        target,
        java.nio.file.StandardCopyOption.REPLACE_EXISTING
      );
    }
    return true;
  } catch (Exception ex) {
    return false;
  }
}

// Lecture robuste avec quelques tentatives pour limiter les collisions de fichiers.
String[] readBridgeTextFile(String targetPath) {
  if (targetPath == null || targetPath.length() == 0) {
    return null;
  }

  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      java.util.List<String> lines = java.nio.file.Files.readAllLines(
        new File(targetPath).toPath(),
        java.nio.charset.StandardCharsets.UTF_8
      );
      return lines.toArray(new String[lines.size()]);
    } catch (Exception ex) {
      // Quelques retries courts suffisent souvent quand le bridge est justement
      // en train d'ecrire le meme fichier au meme instant.
      if (attempt >= 2) {
        return null;
      }
      try {
        Thread.sleep(8);
      } catch (Exception sleepEx) {
        return null;
      }
    }
  }

  return null;
}
