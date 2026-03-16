boolean hasLiveRobotPose = false;
String liveRobotIp = "unknown";
String liveTimestamp = "";
String robotPosePath = "";
String robotCommandPath = "";

float[] liveJoints = {0, 0, 0, 0, 0, 0};
float[] liveCartesian = {300, 0, 200, 180, 0, 0};

int robotPollIntervalMs = 200;
int lastRobotPollMs = -1000;
int lastRobotUpdateMs = -1;

Process robotBridgeProcess = null;
String bridgeLaunchStatus = "not started";
String bridgeExePath = "";
String bridgeCommandStatus = "idle";
int bridgeCommandSequence = 0;

void setupRobotBridge() {
  robotPosePath = sketchPath("robot_pose.csv");
  robotCommandPath = sketchPath(bridgeCommandFileName);
  resetRobotCommandFile();
  setupLocalRobotBridge();
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
    return;
  }

  try {
    String[] command = {
      bridgeExePath,
      "--ip", bridgeTargetIp,
      "--pose-file", robotPosePath,
      "--command-file", robotCommandPath,
      "--poll-ms", str(bridgeLaunchPollMs)
    };
    ProcessBuilder builder = new ProcessBuilder(command);
    builder.redirectErrorStream(true);
    robotBridgeProcess = builder.start();
    bridgeLaunchStatus = "bridge started for " + bridgeTargetIp;
  } catch (Exception ex) {
    bridgeLaunchStatus = "bridge start failed: " + ex.getMessage();
  }
}

public void dispose() {
  stopRobotBridgeProcess();
}

void stopRobotBridgeProcess() {
  if (robotBridgeProcess != null && robotBridgeProcess.isAlive()) {
    robotBridgeProcess.destroy();
    bridgeLaunchStatus = "bridge stopped";
  }
}

void resetRobotCommandFile() {
  File commandFile = new File(robotCommandPath);
  if (commandFile.exists()) {
    commandFile.delete();
  }
  bridgeCommandStatus = "idle";
  bridgeCommandSequence = 0;
}

void updateRobotBridge() {
  if (millis() - lastRobotPollMs < robotPollIntervalMs) {
    return;
  }

  lastRobotPollMs = millis();
  loadRobotPoseFromBridge();
}

void loadRobotPoseFromBridge() {
  File poseFile = new File(robotPosePath);
  if (!poseFile.exists()) {
    hasLiveRobotPose = false;
    return;
  }

  String[] lines = loadStrings(robotPosePath);
  if (lines == null || lines.length == 0) {
    hasLiveRobotPose = false;
    return;
  }

  boolean connected = false;
  String parsedIp = liveRobotIp;
  String parsedTimestamp = liveTimestamp;
  float[] parsedJoints = liveJoints.clone();
  float[] parsedCartesian = liveCartesian.clone();

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
      connected = trim(parts[1]).equals("1");
    } else if (key.equals("ip")) {
      parsedIp = join(subset(parts, 1), ",");
    } else if (key.equals("timestamp")) {
      parsedTimestamp = join(subset(parts, 1), ",");
    } else if (key.equals("joints")) {
      fillFloatArray(parsedJoints, parts, 1);
    } else if (key.equals("cartesian")) {
      fillFloatArray(parsedCartesian, parts, 1);
    }
  }

  liveRobotIp = parsedIp;
  liveTimestamp = parsedTimestamp;
  if (connected) {
    arrayCopy(parsedJoints, liveJoints);
    arrayCopy(parsedCartesian, liveCartesian);
    hasLiveRobotPose = true;
    lastRobotUpdateMs = millis();
  } else {
    hasLiveRobotPose = false;
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
  if (targetJoints == null || targetJoints.length < 6) {
    return;
  }

  bridgeCommandSequence++;
  String[] lines = {
    "sequence," + bridgeCommandSequence,
    "timestamp," + year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "T" + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2),
    "mode,joints",
    "values," + join(formatFloatArray(targetJoints), ",")
  };
  saveStrings(robotCommandPath, lines);
  bridgeCommandStatus = "joint command #" + bridgeCommandSequence + " queued";
}

String[] formatFloatArray(float[] values) {
  String[] formatted = new String[values.length];
  for (int i = 0; i < values.length; i++) {
    formatted[i] = str(values[i]);
  }
  return formatted;
}

String buildFooterStatus() {
  if (hasLiveRobotPose) {
    int ageMs = max(0, millis() - lastRobotUpdateMs);
    return "xArm LIVE | IP: " + liveRobotIp + " | X: " + nf(liveCartesian[0], 1, 1) + " | Y: " + nf(liveCartesian[1], 1, 1) + " | Z: " + nf(liveCartesian[2], 1, 1) + " | " + bridgeCommandStatus + " | age: " + ageMs + " ms";
  }

  return "Waiting for bridge | " + bridgeLaunchStatus;
}

void drawLiveTelemetryCard() {
  float cardWidth = 300;
  float cardHeight = 88;
  float cardX = width - cardWidth - 20;
  float cardY = height - cardHeight - 55;

  noStroke();
  fill(32, 36, 44, 220);
  rect(cardX, cardY, cardWidth, cardHeight, 12);

  fill(hasLiveRobotPose ? color(0, 255, 150) : color(255, 180, 80));
  textAlign(LEFT, TOP);
  textSize(12);
  text(hasLiveRobotPose ? "LIVE ROBOT POSE" : "AUTO BRIDGE", cardX + 14, cardY + 12);

  fill(220);
  textSize(11);
  text("IP: " + bridgeTargetIp, cardX + 14, cardY + 30);
  text("Status: " + bridgeLaunchStatus, cardX + 14, cardY + 46);
  text("CMD: " + bridgeCommandStatus, cardX + 14, cardY + 62);
  textAlign(LEFT, CENTER);
}
