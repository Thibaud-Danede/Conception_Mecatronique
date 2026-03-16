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

void setupRobotBridge() {
  robotPosePath = sketchPath("robot_pose.csv");
  robotCommandPath = sketchPath(bridgeCommandFileName);
  resetRobotPoseFile();
  resetRobotCommandFile();
  clearBridgeRuntimeState();
  setupLocalRobotBridge();
  loadRobotPoseFromBridge();
}

void setupLocalRobotBridge() {
  bridgeExePath = sketchPath(bridgeExecutableRelativePath);
  bridgeLogPath = sketchPath("bridge_launch.log");
  robotPollIntervalMs = bridgeLaunchPollMs;
  registerMethod("dispose", this);

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
    bridgeReconnectInProgress = false;
    return;
  }

  try {
    resetBridgeLogFile();
    String[] command = {
      bridgeExePath,
      "--ip", bridgeTargetIp,
      "--pose-file", robotPosePath,
      "--command-file", robotCommandPath,
      "--poll-ms", str(bridgeLaunchPollMs),
      "--motion-speed", str(bridgeMotionSpeed)
    };
    ProcessBuilder builder = new ProcessBuilder(command);
    builder.redirectErrorStream(true);
    builder.redirectOutput(new File(bridgeLogPath));
    robotBridgeProcess = builder.start();
    bridgeLaunchStatus = bridgeReconnectInProgress
      ? "bridge reconnect started"
      : "bridge started for " + bridgeTargetIp;
  } catch (Exception ex) {
    bridgeLaunchStatus = "bridge start failed: " + ex.getMessage();
    bridgeReconnectInProgress = false;
  }
}

public void dispose() {
  stopRobotBridgeProcess();
}

void stopRobotBridgeProcess() {
  if (robotBridgeProcess != null) {
    try {
      if (robotBridgeProcess.isAlive()) {
        robotBridgeProcess.destroy();
        robotBridgeProcess.destroyForcibly();
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
  File commandFile = new File(robotCommandPath);
  if (commandFile.exists()) {
    commandFile.delete();
  }
  bridgeCommandStatus = "idle";
  bridgeCommandSequence = 0;
  bridgeReportedCommandMode = "none";
  bridgeReportedCommandSequence = 0;
}

void resetRobotPoseFile() {
  File poseFile = new File(robotPosePath);
  if (poseFile.exists()) {
    poseFile.delete();
  }
  hasRobotConnection = false;
  hasLiveRobotPose = false;
  liveRobotStatus = "waiting for bridge";
  liveRobotModeStatus = "real unavailable";
  liveSafetyStatus = "self collision unavailable";
  liveDiagnosticStatus = "diagnostic pending";
  liveDiagnosticNetwork = "web port check pending";
  liveDiagnosticSdk = "SDK check pending";
  lastRobotUpdateMs = -1;
  zeroFloatArray(liveJoints);
  zeroFloatArray(liveCartesian);
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
    refreshBridgeProcessStatus();
    updateReconnectState();
    return;
  }

  lastRobotPollMs = millis();
  refreshBridgeProcessStatus();
  loadRobotPoseFromBridge();
  updateReconnectState();
}

void refreshBridgeProcessStatus() {
  if (robotBridgeProcess == null || robotBridgeProcess.isAlive()) {
    return;
  }

  int exitCode = robotBridgeProcess.exitValue();
  String logTail = readBridgeLogTail();
  bridgeLaunchStatus = "bridge exited (" + exitCode + ")";
  if (logTail.length() > 0) {
    bridgeLaunchStatus += ": " + logTail;
  }
  robotBridgeProcess = null;
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

  String[] lines = loadStrings(robotPosePath);
  if (lines == null || lines.length == 0) {
    hasRobotConnection = false;
    hasLiveRobotPose = false;
    liveRobotStatus = "empty bridge data";
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
  saveStrings(robotCommandPath, lines);
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

  return bridgeLaunchStatus.length() > 0 ? bridgeLaunchStatus : "stopped";
}

void resetBridgeLogFile() {
  if (bridgeLogPath.length() == 0) {
    return;
  }

  File logFile = new File(bridgeLogPath);
  if (logFile.exists()) {
    logFile.delete();
  }
}

String readBridgeLogTail() {
  if (bridgeLogPath.length() == 0) {
    return "";
  }

  File logFile = new File(bridgeLogPath);
  if (!logFile.exists()) {
    return "";
  }

  String[] lines = loadStrings(bridgeLogPath);
  if (lines == null || lines.length == 0) {
    return "";
  }

  for (int i = lines.length - 1; i >= 0; i--) {
    String cleanLine = trim(lines[i]);
    if (cleanLine.length() > 0) {
      return cleanLine;
    }
  }

  return "";
}
