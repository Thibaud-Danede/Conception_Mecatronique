// ============================================================================
// Module capteur de force / liaison serie / auto-nudge.
//
// Ce fichier implemente une petite machine d'etat non bloquante:
// - setupForceSensor() initialise l'etat logique
// - updateForceSensor() est appelee a chaque frame depuis draw()
// - openForceSensorPort() ouvre le port explicitement
// - serialEvent() recoit ensuite les lignes du microcontroleur
// - parseForceSensorLine() met a jour la mesure
// - updateForceSensorAutoNudge() convertit la force en vitesse outil Z
//   via RobotBridge.pde si toutes les conditions de securite sont reunies
//
// Le point important est qu'aucune boucle bloquante n'est utilisee ici:
// la tare, la lecture serie et les commandes robot sont toutes decoupees
// en petites etapes pour ne pas geler le thread graphique Processing.
// ============================================================================

Serial forceSensorPort = null;

// Telemetrie brute du capteur et etat global de la liaison serie.
String forceSensorStatus = "sensor idle";
String forceSensorResolvedPort = "";
String forceSensorLastLine = "";
float forceSensorValue = 0.0;
String forceSensorUnit = "Kg";
boolean forceSensorHadLiveData = false;

// Horodatages utilises pour le polling, le timeout et la reconnexion.
int lastForceSensorRequestMs = -1000;
int lastForceSensorResponseMs = -1;
int forceSensorStartupMs = -1;
int forceSensorLastConnectAttemptMs = -10000;
boolean forceSensorAutoConnectAttempted = false;

// Sequence non bloquante de tare.
boolean forceSensorCalibrationPending = false;
int forceSensorCalibrationStep = 0;
int forceSensorCalibrationNextActionMs = -1;

// Tare automatique lancee apres le boot de l'ESP32.
boolean forceSensorAutoTarePending = false;
int forceSensorAutoTareAtMs = -1;

// Etat du pilotage automatique base sur la force mesuree.
int forceSensorAutoNudgeLastActionMs = -10000;
float forceSensorAutoNudgeLastVelocityMmS = 0.0;
float forceSensorAutoNudgeFilteredForceN = 0.0;
boolean forceSensorAutoNudgeEngaged = false;
String forceSensorAutoNudgeStatus = "force control disabled";
int forceSensorAutoNudgePauseUntilMs = -1;
int forceSensorAutoNudgeLastBridgeSequence = -1;

// Geometrie des boutons dessines dans la carte UI.
float forceBtnCalX = 0;
float forceBtnCalY = 0;
float forceBtnCalW = 0;
float forceBtnCalH = 0;

float forceBtnReconnectX = 0;
float forceBtnReconnectY = 0;
float forceBtnReconnectW = 0;
float forceBtnReconnectH = 0;

// Initialise l'etat logique du module sans ouvrir le port tout de suite.
void setupForceSensor() {
  boolean autoConnectEnabled = forceSensorAutoConnectOnManualTab || forceSensorAutoConnectForSafetyStop;
  // Le capteur peut maintenant etre auto-connecte soit pour le mode manuel,
  // soit simplement pour fournir une mesure fraiche au safety stop global.
  forceSensorStatus = autoConnectEnabled
    ? "waiting for sensor auto connect"
    : "ready to connect";
  forceSensorResolvedPort = "";
  forceSensorHadLiveData = false;
  forceSensorAutoTarePending = false;
  forceSensorAutoTareAtMs = -1;
  resetForceSensorAutoNudgeState(forceSensorAutoNudgeEnabled ? "force control armed" : "force control disabled");
}

// Boucle principale du capteur: connexion, tare auto, mesure, puis conversion eventuelle en commande robot.
void updateForceSensor() {
  boolean manualTabVisible = (menus == 2);
  // Deux cas d'auto-connexion existent:
  // - entree dans l'onglet manuel si forceSensorAutoConnectOnManualTab = true
  // - armement du safety stop global si forceSensorAutoConnectForSafetyStop = true
  boolean shouldAutoConnect = (manualTabVisible && forceSensorAutoConnectOnManualTab) || (forceSafetyStopEnabled && forceSensorAutoConnectForSafetyStop);

  // La connexion automatique peut etre utilisee soit pour l'onglet manuel,
  // soit pour armer l'interlock de securite par effort en fond.
  if (shouldAutoConnect && forceSensorPort == null && millis() - forceSensorLastConnectAttemptMs >= 2000) {
    forceSensorAutoConnectAttempted = true;
    openForceSensorPort();
  }

  if (forceSensorPort == null) {
    return;
  }

  int now = millis();

  if (!isCurrentForceSensorPortStillAvailable()) {
    handleUnexpectedForceSensorDisconnect("sensor usb disconnected");
    return;
  }

  // Cette sous-machine gere les etapes C -> Q -> M sans delay().
  updateForceSensorCalibration();

  // Tant qu'une tare est en cours, aucun pilotage automatique ne doit partir.
  if (forceSensorCalibrationPending) {
    requestForceSensorAutoNudgeStop("force control paused during tare", now);
    return;
  }

  // La tare automatique se place apres le temps de boot du capteur.
  if (forceSensorAutoTarePending) {
    if (now < forceSensorAutoTareAtMs) {
      float remainingSec = max(0, forceSensorAutoTareAtMs - now) / 1000.0;
      forceSensorStatus = "connected - auto tare in " + nf(remainingSec, 1, 1) + "s";
      requestForceSensorAutoNudgeStop("force control waiting for auto tare", now);
      return;
    }

    forceSensorAutoTarePending = false;
    forceSensorAutoTareAtMs = -1;
    forceSensorStatus = "auto tare requested";
    requestForceSensorCalibration();
    requestForceSensorAutoNudgeStop("force control paused during auto tare", now);
    return;
  }

  // On laisse le microcontroleur finir son boot avant de juger le flux de mesure.
  if (now - forceSensorStartupMs < forceSensorWarmupDelayMs) {
    forceSensorStatus = "connected - booting";
    requestForceSensorAutoNudgeStop("force control waiting for warmup", now);
    return;
  }

  if (now - lastForceSensorRequestMs >= forceSensorPollIntervalMs) {
    // Les mesures sont sollicitees explicitement via "M\n". On ne depend pas
    // d'un flux continu venant tout seul du microcontroleur.
    // Cela permet aussi d'avoir un comportement identique pour l'usage manuel
    // et pour l'interlock de securite hors manuel.
    requestForceSensorMeasurement();
    lastForceSensorRequestMs = now;
  }

  if (lastForceSensorResponseMs >= 0 && now - lastForceSensorResponseMs > forceSensorDataTimeoutMs) {
    handleUnexpectedForceSensorDisconnect("sensor timeout");
    return;
  }

  if (!manualTabVisible) {
    // Hors onglet manuel, on garde maintenant les mesures fraiches pour les
    // interlocks de securite, mais on coupe toute reaction auto du robot.
    // Autrement dit:
    // - lecture capteur: OUI
    // - auto-nudge / commande vitesse: NON
    requestForceSensorAutoNudgeStop("force control inactive outside manual tab", now);
    return;
  }

  updateForceSensorAutoNudge(now);
}

// Ouvre explicitement le port configure apres verification qu'il existe encore.
void openForceSensorPort() {
  // On repart toujours d'un etat propre pour eviter qu'un ancien port ou une
  // ancienne tare pendante ne fuient dans la nouvelle connexion.
  closeForceSensorPort();

  forceSensorLastConnectAttemptMs = millis();
  forceSensorResolvedPort = resolveForceSensorPortName();
  forceSensorStatus = forceSensorResolvedPort.length() > 0
    ? "opening " + forceSensorResolvedPort
    : "serial sensor port not found";

  try {
    if (forceSensorResolvedPort.length() == 0) {
      forceSensorResolvedPort = "";
      return;
    }

    forceSensorPort = new Serial(this, forceSensorResolvedPort, forceSensorBaudRate);
    // Processing declenchera serialEvent() a chaque ligne terminee par '\n'.
    forceSensorPort.bufferUntil('\n');
    forceSensorPort.clear();

    forceSensorStartupMs = millis();
    lastForceSensorRequestMs = -1000;
    lastForceSensorResponseMs = -1;
    forceSensorHadLiveData = false;
    forceSensorAutoTarePending = forceSensorAutoTareOnConnect;
    forceSensorAutoTareAtMs = forceSensorAutoTarePending
      ? forceSensorStartupMs + max(0, forceSensorWarmupDelayMs) + max(0, forceSensorAutoTareExtraDelayMs)
      : -1;
    if (forceSensorAutoTarePending) {
      forceSensorStatus = "connected - auto tare scheduled";
    } else {
      forceSensorStatus = "connected - booting";
    }
  }
  catch (Exception ex) {
    forceSensorPort = null;
    forceSensorResolvedPort = "";
    forceSensorStatus = "serial open error";
  }
}

// Demande une mesure ponctuelle au firmware du capteur.
void requestForceSensorMeasurement() {
  if (forceSensorPort == null) {
    return;
  }

  try {
    forceSensorPort.write("M\n");
  }
  catch (Exception ex) {
    handleUnexpectedForceSensorDisconnect("serial write error");
  }
}

// Prepare une tare logicielle sans figer la boucle Processing.
void requestForceSensorCalibration() {
  if (forceSensorPort == null) {
    forceSensorStatus = "calibration impossible - port closed";
    return;
  }

  // On vide l'etat derive pour que la prochaine mesure et la prochaine
  // commande auto repartent d'une base saine.
  lastForceSensorResponseMs = -1;
  lastForceSensorRequestMs = -1000;
  forceSensorValue = 0;
  forceSensorAutoNudgeFilteredForceN = 0;
  forceSensorAutoNudgeLastVelocityMmS = 0;
  forceSensorAutoNudgeEngaged = false;
  forceSensorAutoTarePending = false;
  forceSensorAutoTareAtMs = -1;
  forceSensorCalibrationPending = true;
  forceSensorCalibrationStep = 0;
  forceSensorCalibrationNextActionMs = millis();
  forceSensorStatus = "calibration queued";
}

// Execute la sequence C -> Q -> M sur plusieurs frames.
void updateForceSensorCalibration() {
  if (!forceSensorCalibrationPending || forceSensorPort == null) {
    return;
  }

  int now = millis();
  if (now < forceSensorCalibrationNextActionMs) {
    return;
  }

  try {
    if (forceSensorCalibrationStep == 0) {
      // "C" lance la calibration/tare cote microcontroleur.
      forceSensorPort.write("C\n");
      forceSensorStatus = "calibration start";
      forceSensorCalibrationStep = 1;
      forceSensorCalibrationNextActionMs = now + 300;
    } else if (forceSensorCalibrationStep == 1) {
      // "Q" est ensuite envoye apres une courte attente pour laisser le capteur
      // stabiliser sa nouvelle reference.
      forceSensorPort.write("Q\n");
      forceSensorCalibrationStep = 2;
      forceSensorCalibrationNextActionMs = now + 100;
    } else {
      // Enfin "M" demande tout de suite une mesure post-tare.
      forceSensorPort.write("M\n");
      forceSensorCalibrationPending = false;
      forceSensorCalibrationStep = 0;
      forceSensorCalibrationNextActionMs = -1;
      lastForceSensorRequestMs = now;
      forceSensorStatus = "calibration done";
    }
  }
  catch (Exception ex) {
    handleUnexpectedForceSensorDisconnect("calibration error");
  }
}

// Force une fermeture puis une reouverture du port.
void requestForceSensorReconnect() {
  // La reconnexion repasse volontairement par close + open pour remettre a zero
  // les timers, la tare auto eventuelle et l'etat du controle force.
  forceSensorAutoConnectAttempted = true;
  forceSensorStatus = "reconnecting...";
  closeForceSensorPort();
  openForceSensorPort();
}

// Callback serie Processing: lecture ligne par ligne sans boucle bloquante.
void serialEvent(Serial activePort) {
  if (activePort == null || forceSensorPort == null || activePort != forceSensorPort) {
    return;
  }

  // Comme bufferUntil('\n') est utilise, on lit au plus une ligne complete
  // par callback et on laisse Processing rappeler serialEvent() si besoin.
  String line = activePort.readStringUntil('\n');
  if (line == null) {
    return;
  }

  try {
    line = trim(line);
    if (line.length() > 0) {
      forceSensorLastLine = line;
      parseForceSensorLine(line);
    }
  }
  catch (Exception ex) {
    handleUnexpectedForceSensorDisconnect("serial read error");
  }

  if (forceSensorPort != null && forceSensorPort.available() > forceSensorMaxBufferedBytes) {
    // Garde-fou contre un peripherique qui spammerait trop de donnees.
    forceSensorPort.clear();
    forceSensorStatus = "serial buffer cleared";
  }
}

// Evite de tenter une ouverture sur un nom de port qui n'existe plus.
boolean isConfiguredForceSensorPortAvailable() {
  String[] availablePorts = Serial.list();
  for (int i = 0; i < availablePorts.length; i++) {
    if (availablePorts[i].equalsIgnoreCase(forceSensorComPort)) {
      return true;
    }
  }
  return false;
}

// Parse seulement les messages utiles au sketch.
void parseForceSensorLine(String line) {
  if (line.startsWith("Reading:")) {
    // Format attendu: "Reading: <valeur> <unite>".
    String payload = trim(line.substring(8));
    String[] parts = splitTokens(payload, " ");

    if (parts.length >= 2) {
      forceSensorValue = parseFloatSafe(parts[0], forceSensorValue);
      forceSensorUnit = parts[1];
      lastForceSensorResponseMs = millis();
      forceSensorHadLiveData = true;
      forceSensorStatus = "live";
    }
    return;
  }

  if (line.startsWith("BOOT")) {
    // Les messages de boot sont surtout utiles pour le diagnostic humain.
    forceSensorStatus = "boot message received";
    return;
  }

  if (line.startsWith("CMD")) {
    // Echo firmware volontairement ignore pour ne pas polluer l'etat IHM.
    return;
  }

  if (line.equals("C") || line.equals("Q") || line.equals("M")) {
    return;
  }
}

// Ferme le port et remet a zero tous les etats derives.
void closeForceSensorPort() {
  // Fermer le port implique aussi de couper toute logique de mouvement derivee,
  // sinon on pourrait conserver un dernier ordre de vitesse sans nouvelle mesure.
  forceSensorAutoTarePending = false;
  forceSensorAutoTareAtMs = -1;
  forceSensorCalibrationPending = false;
  forceSensorCalibrationStep = 0;
  forceSensorCalibrationNextActionMs = -1;
  resetForceSensorAutoNudgeState(forceSensorAutoNudgeEnabled ? "force control waiting for sensor" : "force control disabled");

  if (forceSensorPort != null) {
    try {
      forceSensorPort.stop();
    }
    catch (Exception ex) {
    }
  }

  forceSensorPort = null;
  forceSensorResolvedPort = "";
}

// Une mesure est "fraiche" si elle date de moins que le timeout configure.
boolean isForceSensorFresh() {
  // Ce helper est reutilise a la fois pour l'affichage et pour autoriser
  // l'asservissement automatique sur une mesure recente.
  return lastForceSensorResponseMs >= 0 && (millis() - lastForceSensorResponseMs) < forceSensorDataTimeoutMs;
}

// Conversion pratique pour l'affichage secondaire.
float getForceSensorValueKg() {
  // Le firmware peut parler en N ou en Kg selon sa config; l'IHM expose les deux.
  if (forceSensorUnit.equalsIgnoreCase("N")) {
    return forceSensorValue / 9.81;
  }
  return forceSensorValue;
}

// Conversion pratique pour l'asservissement et l'affichage principal.
float getForceSensorValueN() {
  if (forceSensorUnit.equalsIgnoreCase("N")) {
    return forceSensorValue;
  }
  return forceSensorValue * 9.81;
}

// Grande valeur numerique affichee en haut de la carte.
String getForceSensorPrimaryLabel() {
  if (lastForceSensorResponseMs < 0) {
    return "--.-- N";
  }
  return nf(getForceSensorValueN(), 1, 2) + " N";
}

// Valeur secondaire en kg pour l'operateur.
String getForceSensorSecondaryLabel() {
  if (lastForceSensorResponseMs < 0) {
    return "Charge : --.-- kg";
  }
  return "Charge : " + nf(getForceSensorValueKg(), 1, 3) + " kg";
}

// Libelle du bouton de connexion selon l'etat courant.
String getForceSensorReconnectLabel() {
  String targetLabel = getForceSensorRequestedPortLabel();
  return forceSensorPort == null
    ? "Connect " + targetLabel
    : "Reconnect " + targetLabel;
}

String getForceSensorRequestedPortLabel() {
  String preferredPort = trim(forceSensorComPort);
  if (preferredPort.length() > 0) {
    return preferredPort;
  }
  return forceSensorAutoDetectUsbPort ? "USB sensor" : "sensor";
}

String resolveForceSensorPortName() {
  String[] availablePorts = Serial.list();
  if (availablePorts == null || availablePorts.length == 0) {
    return "";
  }

  String preferredPort = trim(forceSensorComPort);
  if (preferredPort.length() > 0) {
    for (int i = 0; i < availablePorts.length; i++) {
      if (availablePorts[i].equalsIgnoreCase(preferredPort)) {
        return availablePorts[i];
      }
    }
    if (!forceSensorAutoDetectUsbPort) {
      return "";
    }
  } else if (!forceSensorAutoDetectUsbPort) {
    return "";
  }

  int bestIndex = -1;
  int bestScore = -100000;
  for (int i = 0; i < availablePorts.length; i++) {
    int candidateScore = scoreForceSensorPortCandidate(availablePorts[i]);
    if (candidateScore > bestScore) {
      bestScore = candidateScore;
      bestIndex = i;
    }
  }

  return bestIndex >= 0 ? availablePorts[bestIndex] : "";
}

int scoreForceSensorPortCandidate(String portName) {
  if (portName == null) {
    return -100000;
  }

  String normalized = trim(portName).toLowerCase();
  int score = 0;
  if (normalized.indexOf("usb") >= 0 || normalized.indexOf("acm") >= 0 || normalized.indexOf("wch") >= 0 ||
    normalized.indexOf("cp210") >= 0 || normalized.indexOf("ch340") >= 0 || normalized.indexOf("serial") >= 0) {
    score += 500;
  }
  if (normalized.startsWith("com")) {
    score += 200;
    score += extractForceSensorComPortNumber(normalized);
  }
  return score;
}

int extractForceSensorComPortNumber(String normalizedPortName) {
  if (normalizedPortName == null || !normalizedPortName.startsWith("com")) {
    return 0;
  }

  String portNumber = normalizedPortName.substring(3);
  try {
    return Integer.parseInt(portNumber);
  } catch (Exception ex) {
    return 0;
  }
}

boolean isCurrentForceSensorPortStillAvailable() {
  if (forceSensorResolvedPort.length() == 0) {
    return forceSensorPort == null;
  }

  String[] availablePorts = Serial.list();
  for (int i = 0; i < availablePorts.length; i++) {
    if (availablePorts[i].equalsIgnoreCase(forceSensorResolvedPort)) {
      return true;
    }
  }
  return false;
}

void handleUnexpectedForceSensorDisconnect(String reason) {
  int now = millis();
  requestForceSensorAutoNudgeStop(reason, now);
  if (measureUseCaseEnabled) {
    disableMeasureUseCase("Measure aborted: " + reason + ".");
  }
  if (forceSensorStopRobotOnDisconnect && canQueueBridgeRequest()) {
    sendRobotStopCommand();
  }
  closeForceSensorPort();
  lastForceSensorResponseMs = -1;
  forceSensorHadLiveData = false;
  forceSensorStatus = reason;
}

// Traduit la force mesuree en une consigne de vitesse outil en Z.
void updateForceSensorAutoNudge(int now) {
  // Flux logique:
  // 1. observer le retour du bridge pour detecter un blocage precedent
  // 2. appliquer un cooldown si necessaire
  // 3. verifier les preconditions capteur + robot + securite
  // 4. filtrer la force
  // 5. appliquer deadband + hysteresis
  // 6. convertir en vitesse cible
  // 7. pousser une commande tool_velocity si le rythme le permet

  // Si le bridge vient de refuser une commande vitesse, on se met en cooldown.
  if (bridgeReportedCommandSequence != forceSensorAutoNudgeLastBridgeSequence) {
    forceSensorAutoNudgeLastBridgeSequence = bridgeReportedCommandSequence;
    String bridgeStatusLower = bridgeCommandStatus.toLowerCase();
    if (bridgeStatusLower.indexOf("tool velocity") >= 0 &&
        (bridgeStatusLower.indexOf("blocked") >= 0 || bridgeStatusLower.indexOf("failed") >= 0)) {
      forceSensorAutoNudgePauseUntilMs = now + 800;
      requestForceSensorAutoNudgeStop("force control paused after bridge safety stop", now);
      return;
    }
  }

  // Protection temporelle apres un blocage ou un arret de securite.
  if (now < forceSensorAutoNudgePauseUntilMs) {
    requestForceSensorAutoNudgeStop("force control cooldown after blocked move", now);
    return;
  }

  // Garde-fous avant d'autoriser la moindre action automatique.
  if (!forceSensorAutoNudgeEnabled) {
    forceSensorAutoNudgeFilteredForceN = 0;
    requestForceSensorAutoNudgeStop("force control disabled", now);
    return;
  }

  if (forceSensorPort == null) {
    forceSensorAutoNudgeFilteredForceN = 0;
    requestForceSensorAutoNudgeStop("force control waiting for sensor", now);
    return;
  }

  if (forceSensorCalibrationPending) {
    requestForceSensorAutoNudgeStop("force control paused during tare", now);
    return;
  }

  if (!isForceSensorFresh()) {
    requestForceSensorAutoNudgeStop("force control waiting for fresh force data", now);
    return;
  }

  if (!hasLiveRobotPose) {
    requestForceSensorAutoNudgeStop("force control waiting for live robot pose", now);
    return;
  }

  if (!canQueueMotionCommand()) {
    requestForceSensorAutoNudgeStop("force control blocked: " + getMotionBlockReason(), now);
    return;
  }

  // Filtre exponentiel + hysteresis pour eviter les oscillations autour de zero.
  float rawForceN = getForceSensorValueN();
  float alpha = constrain(forceSensorAutoNudgeFilterAlpha, 0.01, 1.0);
  forceSensorAutoNudgeFilteredForceN = lerp(forceSensorAutoNudgeFilteredForceN, rawForceN, alpha);

  float targetVelocityMmS = 0.0;
  float absFilteredForceN = abs(forceSensorAutoNudgeFilteredForceN);
  float hysteresisN = max(0.0, forceSensorAutoNudgeHysteresisN);
  float engageThresholdN = forceSensorAutoNudgeDeadbandN + hysteresisN;
  float releaseThresholdN = max(0.0, forceSensorAutoNudgeDeadbandN - hysteresisN);

  if (!forceSensorAutoNudgeEngaged && absFilteredForceN >= engageThresholdN) {
    // On entre dans la zone active seulement au-dessus du seuil d'engagement.
    forceSensorAutoNudgeEngaged = true;
  } else if (forceSensorAutoNudgeEngaged && absFilteredForceN <= releaseThresholdN) {
    // Et on n'en sort qu'une fois repasse sous un seuil plus bas.
    forceSensorAutoNudgeEngaged = false;
  }

  if (forceSensorAutoNudgeEngaged) {
    float effectiveForceN = max(0.0, absFilteredForceN - forceSensorAutoNudgeDeadbandN);
    float velocityMagnitudeMmS = computeForceSensorVelocityMagnitudeMmS(effectiveForceN);
    targetVelocityMmS = forceSensorAutoNudgeFilteredForceN > 0 ? velocityMagnitudeMmS : -velocityMagnitudeMmS;
    if (forceSensorAutoNudgeInvertDirection) {
      targetVelocityMmS = -targetVelocityMmS;
    }
  }

  // On n'envoie pas une commande a chaque frame: seulement si le delai minimal est ecoule.
  int commandIntervalMs = max(20, forceSensorAutoNudgeCommandIntervalMs);
  boolean shouldSendNow = (now - forceSensorAutoNudgeLastActionMs) >= commandIntervalMs;
  boolean mustSendStop = abs(targetVelocityMmS) < 0.01 && abs(forceSensorAutoNudgeLastVelocityMmS) > 0.01;
  if (!shouldSendNow && !mustSendStop) {
    // Rien a envoyer cette frame: on se contente de mettre a jour le texte d'etat.
    if (abs(targetVelocityMmS) < 0.01) {
      forceSensorAutoNudgeStatus = "force control armed +/-" + nf(forceSensorAutoNudgeDeadbandN, 1, 2) + " N (hys " + nf(hysteresisN, 1, 2) + ")";
    } else {
      forceSensorAutoNudgeStatus = "force hold active, target vZ " + nf(targetVelocityMmS, 1, 2) + " mm/s";
    }
    return;
  }

  // La commande bridge est une vitesse outil pure sur l'axe Z.
  float[] toolVelocity = {0, 0, targetVelocityMmS, 0, 0, 0};
  boolean commandQueued = sendRobotToolVelocityCommand(toolVelocity);
  if (!commandQueued) {
    forceSensorAutoNudgeStatus = "force velocity blocked: " + bridgeCommandStatus;
    forceSensorAutoNudgeLastVelocityMmS = 0;
    return;
  }

  forceSensorAutoNudgeLastActionMs = now;
  forceSensorAutoNudgeLastVelocityMmS = targetVelocityMmS;
  if (abs(targetVelocityMmS) < 0.01) {
    forceSensorAutoNudgeStatus = "force neutralized, velocity stop queued";
  } else {
    forceSensorAutoNudgeStatus = "force velocity queued: vZ " + nf(targetVelocityMmS, 1, 2) + " mm/s (F " + nf(rawForceN, 1, 2) + " N)";
  }
}

// Remise a zero complete de l'etat interne du pilotage force -> vitesse.
void resetForceSensorAutoNudgeState(String nextStatus) {
  forceSensorAutoNudgeLastActionMs = -10000;
  forceSensorAutoNudgeLastVelocityMmS = 0;
  forceSensorAutoNudgeFilteredForceN = 0;
  forceSensorAutoNudgeEngaged = false;
  forceSensorAutoNudgePauseUntilMs = -1;
  forceSensorAutoNudgeLastBridgeSequence = bridgeReportedCommandSequence;
  forceSensorAutoNudgeStatus = nextStatus;
}

// Stoppe proprement le pilotage automatique et, si besoin, pousse une vitesse nulle.
void requestForceSensorAutoNudgeStop(String reason, int now) {
  forceSensorAutoNudgeEngaged = false;
  boolean wasMoving = abs(forceSensorAutoNudgeLastVelocityMmS) > 0.01;
  boolean stopQueued = false;

  // Si une vitesse etait en cours, on privilegie d'abord une consigne explicite
  // de vitesse nulle. Sinon, on tente un stop global bridge comme filet de securite.
  if (wasMoving && canQueueMotionCommand()) {
    float[] zeroVelocity = {0, 0, 0, 0, 0, 0};
    stopQueued = sendRobotToolVelocityCommand(zeroVelocity);
  }

  if (stopQueued) {
    forceSensorAutoNudgeLastActionMs = now;
    forceSensorAutoNudgeStatus = reason + " -> velocity stop queued";
  } else if (wasMoving && canQueueBridgeRequest()) {
    sendRobotStopCommand();
    forceSensorAutoNudgeStatus = reason + " -> stop requested";
  } else {
    forceSensorAutoNudgeStatus = reason;
  }

  forceSensorAutoNudgeLastVelocityMmS = 0;
}

// Courbe de reponse non lineaire entre force utile et vitesse Z.
float computeForceSensorVelocityMagnitudeMmS(float effectiveForceN) {
  float velocityMinMmS = max(0.0, forceSensorAutoNudgeVelocityMmSMin);
  float velocityMaxMmS = max(velocityMinMmS + 0.1, forceSensorAutoNudgeVelocityMmSMax);
  float forceForMaxSpeedN = max(0.05, forceSensorAutoNudgeForceForMaxSpeedN);
  float responseExponent = max(0.35, forceSensorAutoNudgeResponseExponent);

  if (effectiveForceN <= 0.0) {
    return 0.0;
  }

  float normalizedForce = constrain(effectiveForceN / forceForMaxSpeedN, 0.0, 1.0);
  float shapedForce = pow(normalizedForce, responseExponent);
  return lerp(velocityMinMmS, velocityMaxMmS, shapedForce);
}

// Interprete les clics sur les boutons de la carte capteur.
boolean handleForceSensorMousePressed(float mx, float my) {
  if (isPointInRect(mx, my, forceBtnCalX, forceBtnCalY, forceBtnCalW, forceBtnCalH)) {
    requestForceSensorCalibration();
    return true;
  }

  if (isPointInRect(mx, my, forceBtnReconnectX, forceBtnReconnectY, forceBtnReconnectW, forceBtnReconnectH)) {
    requestForceSensorReconnect();
    return true;
  }

  return false;
}

// Carte d'etat du capteur de force dans l'onglet manuel.
void drawForceSensorCard(float x, float y, float w, float h) {
  // Lecture visuelle de la carte:
  // - gauche: valeur principale / secondaire
  // - droite: etat technique, auto-nudge, age de mesure
  // - bas droite: actions Tare / Reconnect
  color accent;

  if (forceSensorPort == null) {
    accent = color(255, 120, 120);
  } else if (isForceSensorFresh()) {
    accent = color(0, 255, 150);
  } else {
    accent = color(255, 200, 90);
  }

  noStroke();
  fill(32, 36, 44, 220);
  rect(x, y, w, h, 12);

  textAlign(LEFT, TOP);

  fill(accent);
  textSize(12);
  text("CAPTEUR DE FORCE - " + getForceSensorRequestedPortLabel(), x + 14, y + 10);

  fill(245);
  textSize(28);
  text(getForceSensorPrimaryLabel(), x + 14, y + 30);

  fill(200);
  textSize(12);
  text(getForceSensorSecondaryLabel(), x + 14, y + h - 22);

  float rightX = x + w * 0.52;

  fill(220);
  textSize(12);
  text("Port : " + (forceSensorResolvedPort.equals("") ? "--" : forceSensorResolvedPort), rightX, y + 14);
  text("Statut : " + forceSensorStatus, rightX, y + 32);
  text("Force Ctrl : " + (forceSensorAutoNudgeEnabled ? "ON" : "OFF"), rightX, y + 50);
  text("Action : " + forceSensorAutoNudgeStatus, rightX, y + 68);
  text("Last vZ : " + nf(forceSensorAutoNudgeLastVelocityMmS, 1, 2) + " mm/s", rightX, y + 86);

  if (lastForceSensorResponseMs >= 0) {
    text("Age mesure : " + max(0, millis() - lastForceSensorResponseMs) + " ms", rightX, y + 104);
  } else {
    text("Age mesure : --", rightX, y + 104);
  }

  float btnY = y + h - 42;
  float btnH = 28;
  float btnW = 120;
  float gap = 12;
  boolean canCalibrate = forceSensorPort != null && !forceSensorCalibrationPending;

  forceBtnCalX = rightX;
  forceBtnCalY = btnY;
  forceBtnCalW = btnW;
  forceBtnCalH = btnH;

  forceBtnReconnectX = rightX + btnW + gap;
  forceBtnReconnectY = btnY;
  forceBtnReconnectW = 140;
  forceBtnReconnectH = btnH;

  drawForceActionButton(forceBtnCalX, forceBtnCalY, forceBtnCalW, forceBtnCalH, "Tare", canCalibrate);
  drawForceActionButton(forceBtnReconnectX, forceBtnReconnectY, forceBtnReconnectW, forceBtnReconnectH, getForceSensorReconnectLabel(), true);

  textAlign(LEFT, CENTER);
}

// Bouton visuel reutilisable pour Tare et Reconnect.
void drawForceActionButton(float x, float y, float w, float h, String label, boolean enabled) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  int fillColor = color(54, 60, 70);
  int strokeColor = color(110, 120, 140);

  if (!enabled) {
    fillColor = color(56, 56, 56);
    strokeColor = color(90);
  } else if (isHover) {
    fillColor = color(0, 120, 255);
    strokeColor = color(120, 190, 255);
    cursor(HAND);
  }

  stroke(strokeColor);
  strokeWeight(1.5);
  fill(fillColor);
  rect(x, y, w, h, 9);

  fill(enabled ? color(245) : color(150));
  textAlign(CENTER, CENTER);
  textSize(12);
  text(label, x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}
