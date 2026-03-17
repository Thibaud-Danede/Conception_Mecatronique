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
String bridgeCommandStatus = "idle";
int bridgeCommandSequence = 0;
boolean bridgeReconnectInProgress = false;
int bridgeReconnectStartMs = -1;

boolean bridgeHasPendingCommand = false;
String bridgePendingCommandMode = "none";
float[] bridgePendingCommandValues = {0, 0, 0, 0, 0, 0};
int bridgeLastCommandWriteMs = -1000;
int bridgeCommandWriteMinGapMs = 120;


java.net.http.HttpClient directRobotHttpClient = null;
java.net.http.WebSocket directRobotWebSocket = null;
boolean directRobotWsReady = false;
boolean directRobotWsConnecting = false;
int directRobotWsLastConnectAttemptMs = -1000;
int directRobotWsReconnectIntervalMs = 1000;
int directRobotWsMessageCounter = 0;
String directRobotWsStatus = "direct ws idle";
float directRobotSpeedPercent = 0.45;
float directRobotLastSpeedPercentSent = -1.0;
boolean directRobotCartesianContinuousEnabled = false;

boolean directRobotStepLoopActive = false;
String directRobotStepDirection = "";
int directRobotStepLastKeepAliveMs = -1000;
int directRobotStepKeepAliveMs = 120;
int directRobotStepLastCommandMs = -1000;
int directRobotStepMinGapMs = 60;

void setupRobotBridge() {
  robotPosePath = sketchPath("robot_pose.csv");
  robotCommandPath = sketchPath(bridgeCommandFileName);
  resetRobotPoseFile();
  resetRobotCommandFile();
  clearBridgeRuntimeState();
  setupLocalRobotBridge();
  setupDirectRobotControl();
  loadRobotPoseFromBridge();
}

void setupLocalRobotBridge() {
  bridgeExePath = sketchPath(bridgeExecutableRelativePath);
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
  closeForceSensorPort();
  stopDirectRobotStepMotion();
  closeDirectRobotSocket();
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
  bridgeCommandStatus = "idle";
  bridgeCommandSequence = 0;
  bridgeReportedCommandMode = "none";
  bridgeReportedCommandSequence = 0;
  bridgeLastCommandWriteMs = -1000;
  clearPendingRobotCommand();

  if (robotCommandPath.length() > 0) {
    String[] lines = {
      "sequence,0",
      "timestamp," + buildRobotBridgeTimestamp(),
      "mode,none",
      "values,0,0,0,0,0,0"
    };

    try {
      saveStrings(robotCommandPath, lines);
    }
    catch (Exception ex) {
      bridgeCommandStatus = "reset pending (file busy)";
    }
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
    saveStrings(robotPosePath, lines);
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

void setupDirectRobotControl() {
  if (directRobotHttpClient == null) {
    try {
      directRobotHttpClient = java.net.http.HttpClient.newBuilder()
        .connectTimeout(java.time.Duration.ofMillis(900))
        .build();
      directRobotWsStatus = "direct ws client ready";
    }
    catch (Exception ex) {
      directRobotWsStatus = "direct ws client error";
    }
  }
}

void updateDirectRobotControl() {
  if (directRobotWebSocket == null && !directRobotWsConnecting) {
    ensureDirectRobotSocket();
  }

  if (directRobotStepLoopActive && directRobotWsReady) {
    int now = millis();
    if (now - directRobotStepLastKeepAliveMs >= directRobotStepKeepAliveMs) {
      sendDirectRobotMoveStepOnline();
      directRobotStepLastKeepAliveMs = now;
    }
  }
}

String buildDirectRobotWsUrl() {
  String rawBase = trim(bridgeTargetIp);
  if (rawBase.length() == 0) {
    return "";
  }

  if (!rawBase.startsWith("http://") && !rawBase.startsWith("https://") && !rawBase.startsWith("ws://") && !rawBase.startsWith("wss://")) {
    rawBase = "http://" + rawBase;
  }

  try {
    java.net.URI httpUri = java.net.URI.create(rawBase);
    String host = httpUri.getHost();
    int port = httpUri.getPort();

    if (host == null || host.length() == 0) {
      return "";
    }

    if (port < 0) {
      port = 18333;
    }

    return "ws://" + host + ":" + port + "/ws";
  }
  catch (Exception ex) {
    return "";
  }
}

void ensureDirectRobotSocket() {
  if (directRobotWsReady || directRobotWsConnecting) {
    return;
  }

  if (directRobotHttpClient == null) {
    setupDirectRobotControl();
  }

  String wsUrl = buildDirectRobotWsUrl();
  if (wsUrl.length() == 0) {
    directRobotWsStatus = "direct ws url invalid";
    return;
  }

  if (millis() - directRobotWsLastConnectAttemptMs < directRobotWsReconnectIntervalMs) {
    return;
  }

  directRobotWsLastConnectAttemptMs = millis();
  directRobotWsConnecting = true;
  directRobotWsStatus = "direct ws connecting";

  try {
    directRobotWebSocket = directRobotHttpClient.newWebSocketBuilder()
      .buildAsync(java.net.URI.create(wsUrl), new java.net.http.WebSocket.Listener() {
        public void onOpen(java.net.http.WebSocket webSocket) {
          directRobotWsReady = true;
          directRobotWsConnecting = false;
          directRobotWsStatus = "direct ws connected";
          webSocket.request(1);
        }

        public java.util.concurrent.CompletionStage<?> onText(java.net.http.WebSocket webSocket, CharSequence data, boolean last) {
          directRobotWsStatus = "direct ws connected";
          webSocket.request(1);
          return java.util.concurrent.CompletableFuture.completedFuture(null);
        }

        public java.util.concurrent.CompletionStage<?> onClose(java.net.http.WebSocket webSocket, int statusCode, String reason) {
          directRobotWsReady = false;
          directRobotWsConnecting = false;
          directRobotWebSocket = null;
          directRobotCartesianContinuousEnabled = false;
          directRobotStepLoopActive = false;
          directRobotStepDirection = "";
          directRobotWsStatus = "direct ws closed";
          return java.util.concurrent.CompletableFuture.completedFuture(null);
        }

        public void onError(java.net.http.WebSocket webSocket, Throwable error) {
          directRobotWsReady = false;
          directRobotWsConnecting = false;
          directRobotWebSocket = null;
          directRobotCartesianContinuousEnabled = false;
          directRobotStepLoopActive = false;
          directRobotStepDirection = "";
          directRobotWsStatus = "direct ws error";
        }
      }).join();
  }
  catch (Exception ex) {
    directRobotWsReady = false;
    directRobotWsConnecting = false;
    directRobotWebSocket = null;
    directRobotWsStatus = "direct ws connect failed";
  }
}

void closeDirectRobotSocket() {
  if (directRobotWebSocket != null) {
    try {
      directRobotWebSocket.sendClose(java.net.http.WebSocket.NORMAL_CLOSURE, "bye");
    }
    catch (Exception ex) {
    }
  }

  directRobotWebSocket = null;
  directRobotWsReady = false;
  directRobotWsConnecting = false;
  directRobotCartesianContinuousEnabled = false;
  directRobotStepLoopActive = false;
  directRobotStepDirection = "";
  directRobotWsStatus = "direct ws closed";
}

String nextDirectRobotMessageId() {
  directRobotWsMessageCounter++;
  return "pde_" + directRobotWsMessageCounter;
}

boolean sendDirectRobotWs(String jsonPayload) {
  ensureDirectRobotSocket();

  if (!directRobotWsReady || directRobotWebSocket == null) {
    directRobotWsStatus = "direct ws unavailable";
    return false;
  }

  try {
    directRobotWebSocket.sendText(jsonPayload, true);
    return true;
  }
  catch (Exception ex) {
    directRobotWsReady = false;
    directRobotWsConnecting = false;
    directRobotWebSocket = null;
    directRobotWsStatus = "direct ws send failed";
    return false;
  }
}

float clampDirectRobotSpeedPercent(float percent) {
  return constrain(percent, 0.05, 1.0);
}

String formatJsonNumber(float value) {
  return nf(value, 1, 4);
}

boolean sendDirectRobotSetSpeed(float percent) {
  float clampedPercent = clampDirectRobotSpeedPercent(percent);

  if (abs(clampedPercent - directRobotLastSpeedPercentSent) < 0.02) {
    directRobotSpeedPercent = clampedPercent;
    return true;
  }

  String jsonPayload = "{\"cmd\":\"xarm_set_speed\",\"data\":{\"percent\":" + formatJsonNumber(clampedPercent) + "},\"id\":\"" + nextDirectRobotMessageId() + "\"}";
  boolean sent = sendDirectRobotWs(jsonPayload);
  if (sent) {
    directRobotSpeedPercent = clampedPercent;
    directRobotLastSpeedPercentSent = clampedPercent;
  }
  return sent;
}

boolean sendDirectRobotSwitchMode(int mode) {
  String jsonPayload = "{\"cmd\":\"xarm_switch_mode\",\"data\":{\"mode\":" + mode + "},\"id\":\"" + nextDirectRobotMessageId() + "\"}";
  return sendDirectRobotWs(jsonPayload);
}

boolean sendDirectRobotCartesianContinuous(boolean onOff) {
  if (directRobotCartesianContinuousEnabled == onOff) {
    return true;
  }

  String jsonPayload = "{\"cmd\":\"set_cartesian_velo_continuous\",\"data\":{\"on_off\":" + (onOff ? "true" : "false") + "},\"id\":\"" + nextDirectRobotMessageId() + "\"}";
  boolean sent = sendDirectRobotWs(jsonPayload);
  if (sent) {
    directRobotCartesianContinuousEnabled = onOff;
  }
  return sent;
}

boolean sendDirectRobotMoveStepStart(String direction) {
  String jsonPayload = "{\"cmd\":\"xarm_move_step\",\"data\":{\"isLoop\":true,\"direction\":\"" + direction + "\",\"isMoveTool\":false},\"id\":\"" + nextDirectRobotMessageId() + "\"}";
  return sendDirectRobotWs(jsonPayload);
}

boolean sendDirectRobotMoveStepOnline() {
  String jsonPayload = "{\"cmd\":\"xarm_move_step_online\",\"id\":\"" + nextDirectRobotMessageId() + "\"}";
  return sendDirectRobotWs(jsonPayload);
}

boolean sendDirectRobotMoveStepOver() {
  String jsonPayload = "{\"cmd\":\"xarm_move_step_over\",\"id\":\"" + nextDirectRobotMessageId() + "\"}";
  return sendDirectRobotWs(jsonPayload);
}

boolean requestDirectRobotZStream(float signedPercent) {
  if (!hasRobotConnection || !bridgeRealReady || !bridgeSafetyReady) {
    bridgeCommandStatus = "direct step blocked: " + getMotionBlockReason();
    stopDirectRobotStepMotion();
    return false;
  }

  float requestedPercent = clampDirectRobotSpeedPercent(abs(signedPercent));
  String requestedDirection = signedPercent > 0 ? "position-z-increase" : "position-z-decrease";

  if (!sendDirectRobotSetSpeed(requestedPercent)) {
    bridgeCommandStatus = "direct step blocked: ws unavailable";
    return false;
  }

  sendDirectRobotCartesianContinuous(true);
  sendDirectRobotSwitchMode(2);

  int now = millis();

  if (!directRobotStepLoopActive || !requestedDirection.equals(directRobotStepDirection)) {
    if (directRobotStepLoopActive) {
      sendDirectRobotMoveStepOver();
    }

    boolean started = sendDirectRobotMoveStepStart(requestedDirection);
    if (!started) {
      bridgeCommandStatus = "direct step start failed";
      return false;
    }

    directRobotStepLoopActive = true;
    directRobotStepDirection = requestedDirection;
    directRobotStepLastKeepAliveMs = now;
    directRobotStepLastCommandMs = now;
    bridgeCommandStatus = "direct step " + requestedDirection;
    return true;
  }

  if (now - directRobotStepLastCommandMs >= directRobotStepMinGapMs) {
    sendDirectRobotMoveStepOnline();
    directRobotStepLastKeepAliveMs = now;
    directRobotStepLastCommandMs = now;
  }

  bridgeCommandStatus = "direct step " + requestedDirection;
  return true;
}

void stopDirectRobotStepMotion() {
  if (directRobotStepLoopActive) {
    sendDirectRobotMoveStepOver();
  }

  directRobotStepLoopActive = false;
  directRobotStepDirection = "";
  directRobotStepLastKeepAliveMs = -1000;
  directRobotStepLastCommandMs = -1000;
}

boolean sendDirectRobotCartesianCommand(float[] targetCartesian) {
  return sendDirectRobotCartesianCommand(targetCartesian, 0.70, false);
}

boolean sendDirectRobotCartesianCommand(float[] targetCartesian, float speedPercent, boolean waitMotion) {
  if (targetCartesian == null || targetCartesian.length < 6) {
    return false;
  }

  if (!hasRobotConnection || !bridgeRealReady || !bridgeSafetyReady) {
    bridgeCommandStatus = "direct cartesian blocked: " + getMotionBlockReason();
    return false;
  }

  stopDirectRobotStepMotion();

  if (!sendDirectRobotSetSpeed(speedPercent)) {
    bridgeCommandStatus = "direct cartesian blocked: ws unavailable";
    return false;
  }

  sendDirectRobotCartesianContinuous(true);
  sendDirectRobotSwitchMode(0);

  String jsonPayload = "{\"cmd\":\"xarm_move_arc_line\",\"data\":{" +
    "\"X\":" + formatJsonNumber(targetCartesian[0]) + "," +
    "\"Y\":" + formatJsonNumber(targetCartesian[1]) + "," +
    "\"Z\":" + formatJsonNumber(targetCartesian[2]) + "," +
    "\"A\":" + formatJsonNumber(targetCartesian[3]) + "," +
    "\"B\":" + formatJsonNumber(targetCartesian[4]) + "," +
    "\"C\":" + formatJsonNumber(targetCartesian[5]) + "," +
    "\"R\":0," +
    "\"relative\":false," +
    "\"wait\":" + (waitMotion ? "true" : "false") + "," +
    "\"isControl\":true," +
    "\"module\":\"blockly\"," +
    "\"isClickMove\":false," +
    "\"mode\":0" +
    "},\"id\":\"" + nextDirectRobotMessageId() + "\"}";

  boolean sent = sendDirectRobotWs(jsonPayload);
  if (sent) {
    bridgeCommandStatus = "direct cartesian sent";
  } else {
    bridgeCommandStatus = "direct cartesian failed";
  }
  return sent;
}

void updateRobotBridge() {
  updateDirectRobotControl();
  flushPendingRobotCommand();

  if (millis() - lastRobotPollMs < robotPollIntervalMs) {
    updateReconnectState();
    return;
  }

  lastRobotPollMs = millis();
  loadRobotPoseFromBridge();
  flushPendingRobotCommand();
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

  bridgePendingCommandMode = mode;
  arrayCopy(values, bridgePendingCommandValues);
  bridgeHasPendingCommand = true;
  bridgeCommandStatus = mode + " pending";

  flushPendingRobotCommand();
}

boolean flushPendingRobotCommand() {
  if (!bridgeHasPendingCommand) {
    return false;
  }

  if (robotCommandPath == null || robotCommandPath.length() == 0) {
    bridgeCommandStatus = "command path missing";
    return false;
  }

  int now = millis();
  if (now - bridgeLastCommandWriteMs < bridgeCommandWriteMinGapMs) {
    return false;
  }

  int nextSequence = bridgeCommandSequence + 1;

  String[] lines = {
    "sequence," + nextSequence,
    "timestamp," + buildRobotBridgeTimestamp(),
    "mode," + bridgePendingCommandMode,
    "values," + join(formatFloatArray(bridgePendingCommandValues), ",")
  };

  try {
    saveStrings(robotCommandPath, lines);

    bridgeCommandSequence = nextSequence;
    bridgeReportedCommandMode = bridgePendingCommandMode;
    bridgeReportedCommandSequence = bridgeCommandSequence;
    bridgeCommandStatus = bridgePendingCommandMode + " #" + bridgeCommandSequence + " queued";
    bridgeLastCommandWriteMs = now;
    bridgeHasPendingCommand = false;
    return true;
  }
  catch (Exception ex) {
    bridgeCommandStatus = bridgePendingCommandMode + " pending (file busy)";
    bridgeLastCommandWriteMs = now;
    return false;
  }
}

void clearPendingRobotCommand() {
  bridgeHasPendingCommand = false;
  bridgePendingCommandMode = "none";
  zeroFloatArray(bridgePendingCommandValues);
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
    return connectionLabel + " | " + liveRobotModeStatus + " | " + liveSafetyStatus + " | X: " + nf(liveCartesian[0], 1, 1) + " | Y: " + nf(liveCartesian[1], 1, 1) + " | Z: " + nf(liveCartesian[2], 1, 1) + " | " + bridgeCommandStatus + " | ws: " + directRobotWsStatus + " | bridge: " + bridgeStatus + " | age: " + ageMs + " ms";
  }

  return connectionLabel + " | " + liveRobotStatus + " | diag: " + liveDiagnosticStatus + " | net: " + liveDiagnosticNetwork + " | sdk: " + liveDiagnosticSdk + " | ws: " + directRobotWsStatus + " | bridge: " + bridgeStatus;
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
  text("WS: " + directRobotWsStatus, cardX + 170, cardY + 142);
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
