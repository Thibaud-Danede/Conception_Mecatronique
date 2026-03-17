Serial forceSensorPort = null;

String forceSensorStatus = "sensor idle";
String forceSensorResolvedPort = "";
String forceSensorLastLine = "";
float forceSensorValue = 0.0;
String forceSensorUnit = "Kg";

int lastForceSensorRequestMs = -1000;
int lastForceSensorResponseMs = -1;
int forceSensorStartupMs = -1;
boolean forceSensorAutoConnectAttempted = false;

boolean forceSensorCalibrationPending = false;
int forceSensorCalibrationStep = 0;
int forceSensorCalibrationNextActionMs = -1;

float forceBtnCalX = 0;
float forceBtnCalY = 0;
float forceBtnCalW = 0;
float forceBtnCalH = 0;

float forceBtnReconnectX = 0;
float forceBtnReconnectY = 0;
float forceBtnReconnectW = 0;
float forceBtnReconnectH = 0;

float[] Cartesian = {0, 0, 0, 0, 0, 0};

// ---------- Pilotage continu en Z par effort ----------
int lastForceRobotCommandMs = -1000;

float forceDeadbandN = 0.5;            // zone morte +/- 0.5 N
float forceMinStepZmm = 0.20;          // pas mini par commande
float forceMaxStepZmm = 2.50;          // pas maxi par commande
float forceUsableMaxN = 8.0;           // au-dessus, on sature la vitesse
float forceHardClampN = 12.0;          // sécurité si mauvaise calibration
float forceFilterAlpha = 0.20;         // filtre lissage 0..1
int forceCommandIntervalMs = 180;      // période des commandes continues

float filteredForceN = 0.0;
boolean filteredForceInitialized = false;

void setupForceSensor() {
  forceSensorStatus = forceSensorAutoConnectOnManualTab
    ? "waiting for manual tab"
    : "ready to connect";
}

void updateForceSensor() {
  boolean manualTabVisible = (menus == 2);

  if (manualTabVisible && forceSensorAutoConnectOnManualTab && !forceSensorAutoConnectAttempted && forceSensorPort == null) {
    forceSensorAutoConnectAttempted = true;
    openForceSensorPort();
  }

  if (forceSensorPort == null) {
    return;
  }

  readForceSensorSerial();
  updateForceSensorCalibration();

  if (!manualTabVisible && !forceSensorCalibrationPending) {
    return;
  }

  if (forceSensorCalibrationPending) {
    stopDirectRobotStepMotion();
    return;
  }

  int now = millis();

  if (now - forceSensorStartupMs < forceSensorWarmupDelayMs) {
    stopDirectRobotStepMotion();
    forceSensorStatus = "connected - booting";
    return;
  }

  if (now - lastForceSensorRequestMs >= forceSensorPollIntervalMs) {
    requestForceSensorMeasurement();
    lastForceSensorRequestMs = now;
  }

  if (lastForceSensorResponseMs >= 0 && now - lastForceSensorResponseMs > forceSensorDataTimeoutMs) {
    stopDirectRobotStepMotion();
    forceSensorStatus = "connected - timeout";
  }

  applyContinuousForceToRobotZ();
}

void openForceSensorPort() {
  closeForceSensorPort();

  forceSensorResolvedPort = forceSensorComPort;
  forceSensorStatus = "opening " + forceSensorComPort;

  try {
    forceSensorPort = new Serial(this, forceSensorComPort, forceSensorBaudRate);
    forceSensorPort.clear();

    forceSensorStartupMs = millis();
    lastForceSensorRequestMs = -1000;
    lastForceSensorResponseMs = -1;
    lastForceRobotCommandMs = -1000;
    filteredForceN = 0.0;
    filteredForceInitialized = false;

    forceSensorStatus = "connected - booting";
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

  forceSensorCalibrationPending = true;
  forceSensorCalibrationStep = 0;
  forceSensorCalibrationNextActionMs = millis();
  filteredForceN = 0.0;
  filteredForceInitialized = false;
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
      filteredForceN = 0.0;
      filteredForceInitialized = false;
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

void readForceSensorSerial() {
  if (forceSensorPort == null) {
    return;
  }

  int processedLines = 0;

  while (forceSensorPort != null && forceSensorPort.available() > 0 && processedLines < forceSensorMaxLinesPerUpdate) {
    String line = forceSensorPort.readStringUntil('\n');

    if (line == null) {
      break;
    }

    line = trim(line);

    if (line.length() == 0) {
      continue;
    }

    forceSensorLastLine = line;
    parseForceSensorLine(line);
    processedLines++;
  }

  if (forceSensorPort != null && forceSensorPort.available() > forceSensorMaxBufferedBytes) {
    forceSensorPort.clear();
    forceSensorStatus = "serial buffer cleared";
  }
}

void parseForceSensorLine(String line) {
  if (line.startsWith("Reading:")) {
    String payload = trim(line.substring(8));
    String[] parts = splitTokens(payload, " ");

    if (parts.length >= 2) {
      forceSensorValue = parseFloatSafe(parts[0], forceSensorValue);
      forceSensorUnit = parts[1];
      lastForceSensorResponseMs = millis();
      updateFilteredForce();
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

void updateFilteredForce() {
  float rawN = getForceSensorValueN();

  if (Float.isNaN(rawN) || Float.isInfinite(rawN)) {
    rawN = 0.0;
  }

  rawN = constrain(rawN, -forceHardClampN, forceHardClampN);

  if (!filteredForceInitialized) {
    filteredForceN = rawN;
    filteredForceInitialized = true;
  } else {
    filteredForceN = lerp(filteredForceN, rawN, forceFilterAlpha);
  }
}

float getFilteredForceSensorValueN() {
  if (!filteredForceInitialized) {
    return 0.0;
  }
  return filteredForceN;
}

void applyContinuousForceToRobotZ() {
  if (menus != 2) {
    stopDirectRobotStepMotion();
    return;
  }

  if (forceSensorCalibrationPending) {
    stopDirectRobotStepMotion();
    return;
  }

  if (!isForceSensorFresh()) {
    stopDirectRobotStepMotion();
    return;
  }

  if (!hasRobotConnection || !bridgeRealReady || !bridgeSafetyReady) {
    stopDirectRobotStepMotion();
    return;
  }

  int now = millis();
  if (now - lastForceRobotCommandMs < forceCommandIntervalMs) {
    return;
  }

  float forceN = getFilteredForceSensorValueN();

  if (abs(forceN) <= forceDeadbandN) {
    stopDirectRobotStepMotion();
    return;
  }

  float effort = abs(forceN) - forceDeadbandN;
  float effortSpan = max(0.001, forceUsableMaxN - forceDeadbandN);
  float normalized = constrain(effort / effortSpan, 0.0, 1.0);

  float speedPercent = 0.10 + normalized * 0.75;

  boolean commandSent = false;

  // force > +0.5 N : baisse en Z
  // force < -0.5 N : monte en Z
  if (forceN > forceDeadbandN) {
    commandSent = requestDirectRobotZStream(-speedPercent);
  } else if (forceN < -forceDeadbandN) {
    commandSent = requestDirectRobotZStream(+speedPercent);
  }

  if (commandSent) {
    lastForceRobotCommandMs = now;

    if (forceN > 0) {
      forceSensorStatus = "live - z down direct";
    } else {
      forceSensorStatus = "live - z up direct";
    }
  }
}

void closeForceSensorPort() {
  forceSensorCalibrationPending = false;
  forceSensorCalibrationStep = 0;
  forceSensorCalibrationNextActionMs = -1;
  filteredForceN = 0.0;
  filteredForceInitialized = false;
  stopDirectRobotStepMotion();

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
  return nf(getFilteredForceSensorValueN(), 1, 2) + " N";
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

  if (lastForceSensorResponseMs >= 0) {
    text("Age mesure : " + max(0, millis() - lastForceSensorResponseMs) + " ms", rightX, y + 50);
  } else {
    text("Age mesure : --", rightX, y + 50);
  }

  text("Force filtrée : " + nf(getFilteredForceSensorValueN(), 1, 2) + " N", rightX, y + 68);

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
