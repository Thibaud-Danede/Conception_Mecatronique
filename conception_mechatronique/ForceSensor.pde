Serial forceSensorPort = null;

boolean forceSensorConnected = false;
String forceSensorStatus = "not initialized";
String forceSensorResolvedPort = "";
String forceSensorLastLine = "";
float forceSensorValue = 0.0;
String forceSensorUnit = "Kg";

int lastForceSensorRequestMs = -1000;
int lastForceSensorResponseMs = -1;
int forceSensorStartupMs = -1;
int lastForceSensorConnectAttemptMs = -10000;

// Boutons UI
float forceBtnCalX = 0;
float forceBtnCalY = 0;
float forceBtnCalW = 0;
float forceBtnCalH = 0;

float forceBtnReconnectX = 0;
float forceBtnReconnectY = 0;
float forceBtnReconnectW = 0;
float forceBtnReconnectH = 0;

void setupForceSensor() {
  openForceSensorPort();
}

void openForceSensorPort() {
  lastForceSensorConnectAttemptMs = millis();
  closeForceSensorPort();

  forceSensorStatus = "searching " + forceSensorComPort;
  forceSensorResolvedPort = "";

  String[] ports = Serial.list();

  if (ports == null || ports.length == 0) {
    forceSensorStatus = "no serial port found";
    return;
  }

  String wanted = forceSensorComPort.toUpperCase();
  String matchedPort = "";

  for (String p : ports) {
    String candidate = p.toUpperCase();
    if (candidate.equals(wanted) || candidate.indexOf(wanted) >= 0) {
      matchedPort = p;
      break;
    }
  }

  if (matchedPort.equals("")) {
    forceSensorStatus = forceSensorComPort + " not found";
    return;
  }

  try {
    forceSensorPort = new Serial(this, matchedPort, forceSensorBaudRate);
    forceSensorPort.clear();

    forceSensorResolvedPort = matchedPort;
    forceSensorConnected = true;
    forceSensorStartupMs = millis();
    lastForceSensorRequestMs = -1000;
    lastForceSensorResponseMs = -1;
    forceSensorStatus = "connected - booting";
  }
  catch (Exception ex) {
    forceSensorPort = null;
    forceSensorConnected = false;
    forceSensorStatus = "serial open error";
  }
}

void updateForceSensor() {
  if (forceSensorPort == null) {
    if (millis() - lastForceSensorConnectAttemptMs >= forceSensorReconnectIntervalMs) {
      openForceSensorPort();
    }
    return;
  }

  readForceSensorSerial();

  int now = millis();

  if (now - forceSensorStartupMs < forceSensorWarmupDelayMs) {
    forceSensorStatus = "connected - booting";
    return;
  }

  if (now - lastForceSensorRequestMs >= forceSensorPollIntervalMs) {
    requestForceSensorMeasurement();
    lastForceSensorRequestMs = now;
  }

  if (lastForceSensorResponseMs >= 0 && now - lastForceSensorResponseMs > 1500) {
    forceSensorStatus = "connected - timeout";
  }
}

void requestForceSensorMeasurement() {
  if (forceSensorPort == null) return;

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

  try {
    forceSensorStatus = "calibration start";
    forceSensorPort.write("C\n");
    delay(300);
    forceSensorPort.write("Q\n");
    delay(100);
    forceSensorPort.write("M\n");
    forceSensorStatus = "calibration done";
  }
  catch (Exception ex) {
    forceSensorStatus = "calibration error";
    closeForceSensorPort();
  }
}

void requestForceSensorReconnect() {
  forceSensorStatus = "reconnecting...";
  closeForceSensorPort();
  delay(120);
  openForceSensorPort();
}

void readForceSensorSerial() {
  if (forceSensorPort == null) return;

  while (forceSensorPort.available() > 0) {
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
  }
}

void parseForceSensorLine(String line) {
  if (line.startsWith("Reading:")) {
    String payload = trim(line.substring(8));
    String[] parts = splitTokens(payload, " ");

    if (parts.length >= 2) {
      float parsedValue = parseFloatSafe(parts[0], forceSensorValue);
      forceSensorValue = parsedValue;
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

  if (line.equals("C")) {
    return;
  }

  if (line.equals("Q")) {
    return;
  }

  if (line.equals("M")) {
    return;
  }
}

void closeForceSensorPort() {
  if (forceSensorPort != null) {
    try {
      forceSensorPort.stop();
    }
    catch (Exception ex) {
    }
  }

  forceSensorPort = null;
  forceSensorConnected = false;
}

boolean isForceSensorFresh() {
  return lastForceSensorResponseMs >= 0 && (millis() - lastForceSensorResponseMs) < 1500;
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
  text("Port detecte : " + (forceSensorResolvedPort.equals("") ? "--" : forceSensorResolvedPort), rightX, y + 14);
  text("Statut : " + forceSensorStatus, rightX, y + 32);

  if (lastForceSensorResponseMs >= 0) {
    text("Age mesure : " + max(0, millis() - lastForceSensorResponseMs) + " ms", rightX, y + 50);
  } else {
    text("Age mesure : --", rightX, y + 50);
  }

  float btnY = y + h - 42;
  float btnH = 28;
  float btnW = 120;
  float gap = 12;

  forceBtnCalX = rightX;
  forceBtnCalY = btnY;
  forceBtnCalW = btnW;
  forceBtnCalH = btnH;

  forceBtnReconnectX = rightX + btnW + gap;
  forceBtnReconnectY = btnY;
  forceBtnReconnectW = 140;
  forceBtnReconnectH = btnH;

  drawForceActionButton(forceBtnCalX, forceBtnCalY, forceBtnCalW, forceBtnCalH, "Calibration", true);
  drawForceActionButton(forceBtnReconnectX, forceBtnReconnectY, forceBtnReconnectW, forceBtnReconnectH, "Relancer COM4", true);

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
