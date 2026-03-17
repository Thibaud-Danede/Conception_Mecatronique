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

boolean bridgeRealReady = false;
boolean bridgeSafetyReady = false;
boolean bridgeValidationPassed = false;
int bridgeReportedCommandSequence = 0;
String bridgeReportedCommandMode = "none";
String bridgeValidationStatus = "not validated";

float[] liveJoints = {0, 0, 0, 0, 0, 0};
float[] liveCartesian = {0, 0, 0, 0, 0, 0};
float[] bridgeValidationTarget = {0, 0, 0, 0, 0, 0};
float[] bridgeValidationJoints = {0, 0, 0, 0, 0, 0};

int robotPollIntervalMs = 200;
int lastRobotPollMs = -1000;
int lastRobotUpdateMs = -1;

Process robotBridgeProcess = null;
String bridgeLaunchStatus = "not started";
String bridgeExePath = "";
String bridgeLogPath = "";
String bridgeCommandStatus = "idle";
int bridgeCommandSequence = 0;
boolean bridgeReconnectInProgress = false;
int bridgeReconnectStartMs = -1;
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

void setupRobotBridge() {
  robotPosePath = sketchPath("robot_pose.csv");
  robotCommandPath = sketchPath(bridgeCommandFileName);
  bridgeLogPath = bridgeDiagnosticLogEnabled ? sketchPath("bridge_launch.log") : "";
  resetRobotPoseFile();
  resetRobotCommandFile();
  clearBridgeRuntimeState();
  setupLocalRobotBridge();
  loadRobotPoseFromBridge();
}

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
    if (currentPath == null || currentPath.length() == 0) {
      builder.environment().put("PATH", binPath);
    } else {
      builder.environment().put("PATH", binPath + File.pathSeparator + currentPath);
    }

    robotBridgeProcess = builder.start();
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

public void dispose() {
  closeForceSensorPort();
  stopRobotBridgeProcess();
  cleanupStaleRobotBridgeProcessesIfNeeded();
}

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

void requestRobotBridgeReconnect() {
  if (bridgeReconnectInProgress) {
    return;
  }

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

void resetRobotCommandFile() {
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

void resetRobotPoseFile() {
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

void clearBridgeRuntimeState() {
  bridgeRealReady = false;
  bridgeSafetyReady = false;
  bridgeValidationPassed = false;
  bridgeValidationStatus = "not validated";
  zeroFloatArray(bridgeValidationTarget);
  zeroFloatArray(bridgeValidationJoints);
}

void updateRobotBridge() {
  if (millis() - lastRobotPollMs < robotPollIntervalMs) {
    updateReconnectState();
    return;
  }

  lastRobotPollMs = millis();
  loadRobotPoseFromBridge();
  updateReconnectState();
}

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

void fillFloatArray(float[] target, String[] parts, int offset) {
  for (int i = 0; i < target.length; i++) {
    int sourceIndex = i + offset;
    if (sourceIndex < parts.length) {
      target[i] = parseFloatSafe(parts[sourceIndex], target[i]);
    }
  }
}

void zeroFloatArray(float[] values) {
  for (int i = 0; i < values.length; i++) {
    values[i] = 0;
  }
}

float parseFloatSafe(String rawValue, float fallbackValue) {
  String normalized = trim(rawValue);
  normalized = normalized.replace(',', '.');
  float parsedValue = parseFloat(normalized);
  if (Float.isNaN(parsedValue)) {
    return fallbackValue;
  }

  return parsedValue;
}

void sendRobotJointCommand(float[] targetJoints) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "joint command blocked: " + getMotionBlockReason();
    return;
  }

  sendRobotCommand("joints", targetJoints);
}

boolean sendRobotHomeCommand() {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "home command blocked: " + getMotionBlockReason();
    return false;
  }

  float[] neutralValues = {0, 0, 0, 0, 0, 0};
  sendRobotCommand("move_home", neutralValues);
  return true;
}

boolean sendRobotToolDeltaCommand(float[] deltaToolPose) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "tool delta blocked: " + getMotionBlockReason();
    return false;
  }

  sendRobotCommand("tool_delta", deltaToolPose);
  return true;
}

boolean sendRobotToolVelocityCommand(float[] toolVelocity) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "tool velocity blocked: " + getMotionBlockReason();
    return false;
  }

  sendRobotCommand("tool_velocity", toolVelocity);
  return true;
}

boolean sendRobotStopCommand() {
  if (!canQueueBridgeRequest()) {
    bridgeCommandStatus = "stop blocked: bridge unavailable";
    return false;
  }

  float[] neutralValues = {0, 0, 0, 0, 0, 0};
  sendRobotCommand("stop_motion", neutralValues);
  return true;
}

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

boolean sendRobotCartesianExecuteCommand(float[] targetCartesian) {
  if (!canQueueBridgeRequest()) {
    bridgeCommandStatus = "execute blocked: bridge unavailable";
    return false;
  }

  if (!isCurrentMgiTargetValidated()) {
    bridgeCommandStatus = "execute blocked: validate the current target first";
    return false;
  }

  sendRobotCommand("cartesian_ik_execute", targetCartesian);
  return true;
}

void sendRobotCommand(String mode, float[] values) {
  if (values == null || values.length < 6) {
    return;
  }

  bridgeCommandSequence++;
  String[] lines = {
    "sequence," + bridgeCommandSequence,
    "timestamp," + year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "T" + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2),
    "mode," + mode,
    "values," + join(formatFloatArray(values), ",")
  };
  queueRobotCommandFileWrite(lines);
  bridgeReportedCommandMode = mode;
  bridgeReportedCommandSequence = bridgeCommandSequence;
  bridgeCommandStatus = mode + " #" + bridgeCommandSequence + " queued";
}

boolean canQueueBridgeRequest() {
  return !bridgeReconnectInProgress && robotBridgeProcess != null && robotBridgeProcess.isAlive();
}

boolean canQueueMotionCommand() {
  return canQueueBridgeRequest() && hasRobotConnection && bridgeRealReady && bridgeSafetyReady;
}

String getMotionBlockReason() {
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

String[] formatFloatArray(float[] values) {
  String[] formatted = new String[values.length];
  for (int i = 0; i < values.length; i++) {
    formatted[i] = str(values[i]);
  }
  return formatted;
}

String buildRobotBridgeTimestamp() {
  return year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "T" + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
}

String buildFooterStatus() {
  String bridgeStatus = getBridgeRuntimeStatus();
  String connectionLabel = hasRobotConnection ? "xArm CONNECTED" : "xArm DISCONNECTED";
  if (hasLiveRobotPose) {
    int ageMs = max(0, millis() - lastRobotUpdateMs);
    return connectionLabel + " | " + liveRobotModeStatus + " | " + liveSafetyStatus + " | X: " + nf(liveCartesian[0], 1, 1) + " | Y: " + nf(liveCartesian[1], 1, 1) + " | Z: " + nf(liveCartesian[2], 1, 1) + " | " + bridgeCommandStatus + " | bridge: " + bridgeStatus + " | age: " + ageMs + " ms";
  }

  return connectionLabel + " | " + liveRobotStatus + " | diag: " + liveDiagnosticStatus + " | net: " + liveDiagnosticNetwork + " | sdk: " + liveDiagnosticSdk + " | bridge: " + bridgeStatus;
}

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

void queueRobotCommandFileWrite(String[] lines) {
  if (robotCommandPath.length() == 0 || lines == null) {
    return;
  }

  synchronized (robotCommandIoLock) {
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
      continue;
    }

    robotCommandIoStatus = writeBridgeTextFileNow(targetPath, linesToWrite)
      ? "write ok"
      : "write failed";
  }
}

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
