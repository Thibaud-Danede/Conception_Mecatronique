Serial forceSensorPort = null;

String forceSensorStatus = "sensor idle";
String forceSensorResolvedPort = "";
String forceSensorLastLine = "";
float forceSensorValue = 0.0;
String forceSensorUnit = "Kg";

int lastForceSensorRequestMs = -1000;
int lastForceSensorResponseMs = -1;
int forceSensorStartupMs = -1;
int forceSensorLastConnectAttemptMs = -10000;
boolean forceSensorAutoConnectAttempted = false;

boolean forceSensorCalibrationPending = false;
int forceSensorCalibrationStep = 0;
int forceSensorCalibrationNextActionMs = -1;
boolean forceSensorAutoTarePending = false;
int forceSensorAutoTareAtMs = -1;
int forceSensorAutoNudgeLastActionMs = -10000;
float forceSensorAutoNudgeLastVelocityMmS = 0.0;
float forceSensorAutoNudgeFilteredForceN = 0.0;
boolean forceSensorAutoNudgeEngaged = false;
String forceSensorAutoNudgeStatus = "force control disabled";
int forceSensorAutoNudgePauseUntilMs = -1;
int forceSensorAutoNudgeLastBridgeSequence = -1;

float forceBtnCalX = 0;
float forceBtnCalY = 0;
float forceBtnCalW = 0;
float forceBtnCalH = 0;

float forceBtnReconnectX = 0;
float forceBtnReconnectY = 0;
float forceBtnReconnectW = 0;
float forceBtnReconnectH = 0;

void setupForceSensor() {
  forceSensorStatus = forceSensorAutoConnectOnManualTab
    ? "waiting for manual tab"
    : "ready to connect";
  forceSensorAutoTarePending = false;
  forceSensorAutoTareAtMs = -1;
  resetForceSensorAutoNudgeState(forceSensorAutoNudgeEnabled ? "force control armed" : "force control disabled");
}

void updateForceSensor() {
  boolean manualTabVisible = (menus == 2);

  if (manualTabVisible && forceSensorAutoConnectOnManualTab && forceSensorPort == null && millis() - forceSensorLastConnectAttemptMs >= 2000) {
    forceSensorAutoConnectAttempted = true;
    openForceSensorPort();
  }

  if (forceSensorPort == null) {
    return;
  }

  int now = millis();
  updateForceSensorCalibration();

  if (forceSensorCalibrationPending) {
    requestForceSensorAutoNudgeStop("force control paused during tare", now);
    return;
  }

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

  if (!manualTabVisible) {
    return;
  }

  if (now - forceSensorStartupMs < forceSensorWarmupDelayMs) {
    forceSensorStatus = "connected - booting";
    requestForceSensorAutoNudgeStop("force control waiting for warmup", now);
    return;
  }

  if (now - lastForceSensorRequestMs >= forceSensorPollIntervalMs) {
    requestForceSensorMeasurement();
    lastForceSensorRequestMs = now;
  }

  if (lastForceSensorResponseMs >= 0 && now - lastForceSensorResponseMs > forceSensorDataTimeoutMs) {
    forceSensorStatus = "connected - timeout";
  }

  updateForceSensorAutoNudge(now);
}

void openForceSensorPort() {
  closeForceSensorPort();

  forceSensorLastConnectAttemptMs = millis();
  forceSensorResolvedPort = forceSensorComPort;
  forceSensorStatus = "opening " + forceSensorComPort;

  try {
    if (!isConfiguredForceSensorPortAvailable()) {
      forceSensorResolvedPort = "";
      forceSensorStatus = "serial port not found: " + forceSensorComPort;
      return;
    }

    forceSensorPort = new Serial(this, forceSensorComPort, forceSensorBaudRate);
    forceSensorPort.bufferUntil('\n');
    forceSensorPort.clear();

    forceSensorStartupMs = millis();
    lastForceSensorRequestMs = -1000;
    lastForceSensorResponseMs = -1;
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
    forceSensorStatus = "serial open error on " + forceSensorComPort;
  }
}

void requestForceSensorMeasurement() {
  if (forceSensorPort == null) {
    return;
  }

  try {
    forceSensorPort.write("M\n");
  }
  catch (Exception ex) {
    forceSensorStatus = "serial write error";
    closeForceSensorPort();
  }
}

void requestForceSensorCalibration() {
  if (forceSensorPort == null) {
    forceSensorStatus = "calibration impossible - port closed";
    return;
  }

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
      forceSensorPort.write("C\n");
      forceSensorStatus = "calibration start";
      forceSensorCalibrationStep = 1;
      forceSensorCalibrationNextActionMs = now + 300;
    } else if (forceSensorCalibrationStep == 1) {
      forceSensorPort.write("Q\n");
      forceSensorCalibrationStep = 2;
      forceSensorCalibrationNextActionMs = now + 100;
    } else {
      forceSensorPort.write("M\n");
      forceSensorCalibrationPending = false;
      forceSensorCalibrationStep = 0;
      forceSensorCalibrationNextActionMs = -1;
      lastForceSensorRequestMs = now;
      forceSensorStatus = "calibration done";
    }
  }
  catch (Exception ex) {
    forceSensorStatus = "calibration error";
    closeForceSensorPort();
  }
}

void requestForceSensorReconnect() {
  forceSensorAutoConnectAttempted = true;
  forceSensorStatus = "reconnecting...";
  closeForceSensorPort();
  openForceSensorPort();
}

void serialEvent(Serial activePort) {
  if (activePort == null || forceSensorPort == null || activePort != forceSensorPort) {
    return;
  }

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
    forceSensorStatus = "serial read error";
    closeForceSensorPort();
  }

  if (forceSensorPort != null && forceSensorPort.available() > forceSensorMaxBufferedBytes) {
    forceSensorPort.clear();
    forceSensorStatus = "serial buffer cleared";
  }
}

boolean isConfiguredForceSensorPortAvailable() {
  String[] availablePorts = Serial.list();
  for (int i = 0; i < availablePorts.length; i++) {
    if (availablePorts[i].equalsIgnoreCase(forceSensorComPort)) {
      return true;
    }
  }
  return false;
}

void parseForceSensorLine(String line) {
  if (line.startsWith("Reading:")) {
    String payload = trim(line.substring(8));
    String[] parts = splitTokens(payload, " ");

    if (parts.length >= 2) {
      forceSensorValue = parseFloatSafe(parts[0], forceSensorValue);
      forceSensorUnit = parts[1];
      lastForceSensorResponseMs = millis();
      forceSensorStatus = "live";
    }
    return;
  }

  if (line.startsWith("BOOT")) {
    forceSensorStatus = "boot message received";
    return;
  }

  if (line.startsWith("CMD")) {
    return;
  }

  if (line.equals("C") || line.equals("Q") || line.equals("M")) {
    return;
  }
}

void closeForceSensorPort() {
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
}

boolean isForceSensorFresh() {
  return lastForceSensorResponseMs >= 0 && (millis() - lastForceSensorResponseMs) < forceSensorDataTimeoutMs;
}

float getForceSensorValueKg() {
  if (forceSensorUnit.equalsIgnoreCase("N")) {
    return forceSensorValue / 9.81;
  }
  return forceSensorValue;
}

float getForceSensorValueN() {
  if (forceSensorUnit.equalsIgnoreCase("N")) {
    return forceSensorValue;
  }
  return forceSensorValue * 9.81;
}

String getForceSensorPrimaryLabel() {
  if (lastForceSensorResponseMs < 0) {
    return "--.-- N";
  }
  return nf(getForceSensorValueN(), 1, 2) + " N";
}

String getForceSensorSecondaryLabel() {
  if (lastForceSensorResponseMs < 0) {
    return "Charge : --.-- kg";
  }
  return "Charge : " + nf(getForceSensorValueKg(), 1, 3) + " kg";
}

String getForceSensorReconnectLabel() {
  return forceSensorPort == null
    ? "Connect " + forceSensorComPort
    : "Reconnect " + forceSensorComPort;
}

void updateForceSensorAutoNudge(int now) {
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

  if (now < forceSensorAutoNudgePauseUntilMs) {
    requestForceSensorAutoNudgeStop("force control cooldown after blocked move", now);
    return;
  }

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

  float rawForceN = getForceSensorValueN();
  float alpha = constrain(forceSensorAutoNudgeFilterAlpha, 0.01, 1.0);
  forceSensorAutoNudgeFilteredForceN = lerp(forceSensorAutoNudgeFilteredForceN, rawForceN, alpha);

  float targetVelocityMmS = 0.0;
  float absFilteredForceN = abs(forceSensorAutoNudgeFilteredForceN);
  float hysteresisN = max(0.0, forceSensorAutoNudgeHysteresisN);
  float engageThresholdN = forceSensorAutoNudgeDeadbandN + hysteresisN;
  float releaseThresholdN = max(0.0, forceSensorAutoNudgeDeadbandN - hysteresisN);

  if (!forceSensorAutoNudgeEngaged && absFilteredForceN >= engageThresholdN) {
    forceSensorAutoNudgeEngaged = true;
  } else if (forceSensorAutoNudgeEngaged && absFilteredForceN <= releaseThresholdN) {
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

  int commandIntervalMs = max(20, forceSensorAutoNudgeCommandIntervalMs);
  boolean shouldSendNow = (now - forceSensorAutoNudgeLastActionMs) >= commandIntervalMs;
  boolean mustSendStop = abs(targetVelocityMmS) < 0.01 && abs(forceSensorAutoNudgeLastVelocityMmS) > 0.01;
  if (!shouldSendNow && !mustSendStop) {
    if (abs(targetVelocityMmS) < 0.01) {
      forceSensorAutoNudgeStatus = "force control armed +/-" + nf(forceSensorAutoNudgeDeadbandN, 1, 2) + " N (hys " + nf(hysteresisN, 1, 2) + ")";
    } else {
      forceSensorAutoNudgeStatus = "force hold active, target vZ " + nf(targetVelocityMmS, 1, 2) + " mm/s";
    }
    return;
  }

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

void resetForceSensorAutoNudgeState(String nextStatus) {
  forceSensorAutoNudgeLastActionMs = -10000;
  forceSensorAutoNudgeLastVelocityMmS = 0;
  forceSensorAutoNudgeFilteredForceN = 0;
  forceSensorAutoNudgeEngaged = false;
  forceSensorAutoNudgePauseUntilMs = -1;
  forceSensorAutoNudgeLastBridgeSequence = bridgeReportedCommandSequence;
  forceSensorAutoNudgeStatus = nextStatus;
}

void requestForceSensorAutoNudgeStop(String reason, int now) {
  forceSensorAutoNudgeEngaged = false;
  boolean wasMoving = abs(forceSensorAutoNudgeLastVelocityMmS) > 0.01;
  boolean stopQueued = false;

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

void drawForceSensorCard(float x, float y, float w, float h) {
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
  text("CAPTEUR DE FORCE - " + forceSensorComPort, x + 14, y + 10);

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
