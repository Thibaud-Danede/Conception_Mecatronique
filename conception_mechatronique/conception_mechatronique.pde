import java.io.File;
import processing.serial.*;

float[] joints = {0, 0, 0, 0, 0, 0};
String[] names = {"J1: Base", "J2: Epaule", "J3: Coude", "J4: Poignet 1", "J5: Poignet 2", "J6: Poignet 3"};
int menus = 0;
boolean homeButtonHoldActive = false;

void setup() {
  size(900, 600);
  surface.setResizable(true);
  textAlign(LEFT, CENTER);

  setupRobotBridge();
  setupMgiUi();
  setupForceSensor();
}

void draw() {
  background(25);

  updateRobotBridge();
  updateForceSensor();
  cursor(ARROW);

  drawHeader();

  if (menus == 0) {
    draw_menus_1();
  } else if (menus == 1) {
    draw_menus_2();
  } else if (menus == 2) {
    draw_menus_3();
  }

  drawLiveTelemetryCard();
  drawFooter();
}

void drawHeader() {
  float headerHeight = 60;
  float homeButtonWidth = 96;
  float reconnectButtonWidth = 132;
  float reconnectButtonHeight = 34;
  float reconnectButtonX = width - reconnectButtonWidth - 18;
  float homeButtonX = reconnectButtonX - homeButtonWidth - 10;
  float reconnectButtonY = 13;
  float tabAreaWidth = homeButtonX - 12;
  float tabWidth = tabAreaWidth / 3.0;

  noStroke();
  fill(40);
  rect(0, 0, width, headerHeight);

  drawTab(0, 0, tabWidth, headerHeight, "MODELE GEOMETRIQUE DIRECT (MGD)", 0);
  drawTab(tabWidth, 0, tabWidth, headerHeight, "MODELE GEOMETRIQUE INVERSE (MGI)", 1);
  drawTab(2 * tabWidth, 0, tabWidth, headerHeight, "CONTROL MANUELLE", 2);
  drawHomeButton(homeButtonX, reconnectButtonY, homeButtonWidth, reconnectButtonHeight);
  drawReconnectButton(reconnectButtonX, reconnectButtonY, reconnectButtonWidth, reconnectButtonHeight);

  stroke(0, 120, 255);
  strokeWeight(2);
  line(0, headerHeight, width, headerHeight);
}

void drawTab(float x, float y, float w, float h, String label, int id) {
  boolean isSelected = (menus == id);
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);

  if (isSelected) {
    fill(60);
  } else if (isHover) {
    fill(50);
    cursor(HAND);
  } else {
    fill(40);
  }

  noStroke();
  rect(x, y, w, h);

  textAlign(CENTER, CENTER);
  textSize(14);
  if (isSelected) {
    fill(0, 255, 150);
    rect(x + 20, y + h - 5, w - 40, 3);
  } else {
    fill(200);
  }
  text(label, x + w / 2, y + h / 2);

  textAlign(LEFT, CENTER);
}

void drawReconnectButton(float x, float y, float w, float h) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  boolean isEnabled = !bridgeReconnectInProgress;
  int fillColor = color(54, 60, 70);
  int strokeColor = color(110, 120, 140);

  if (!isEnabled) {
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
  rect(x, y, w, h, 10);

  fill(isEnabled ? color(240) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(bridgeReconnectInProgress ? "Reconnecting..." : "Reconnect", x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}

void drawHomeButton(float x, float y, float w, float h) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  boolean isEnabled = canQueueMotionCommand() || homeButtonHoldActive;
  int fillColor = color(54, 60, 70);
  int strokeColor = color(110, 120, 140);

  if (homeButtonHoldActive) {
    fillColor = color(0, 160, 110);
    strokeColor = color(120, 220, 180);
  } else if (!isEnabled) {
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
  rect(x, y, w, h, 10);

  fill(isEnabled ? color(240) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(homeButtonHoldActive ? "Hold Home" : "Home", x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}

void drawFooter() {
  fill(40);
  noStroke();
  rect(0, height - 40, width, 40);

  fill(150);
  textSize(12);
  text(buildFooterStatus(), 20, height - 20);
}

void mousePressed() {
  if (handleHeaderMousePressed(mouseX, mouseY)) {
    return;
  }

  if (menus == 2) {
    if (handleForceSensorMousePressed(mouseX, mouseY)) {
      return;
    }
  }

  if (menus == 1) {
    handleMgiMousePressed(mouseX, mouseY);
  }
}

void mouseReleased() {
  if (homeButtonHoldActive) {
    homeButtonHoldActive = false;
    sendRobotStopCommand();
  }

  handleMgiMouseReleased();
}

boolean handleHeaderMousePressed(float px, float py) {
  float headerHeight = 60;
  float homeButtonWidth = 96;
  float reconnectButtonWidth = 132;
  float reconnectButtonHeight = 34;
  float reconnectButtonX = width - reconnectButtonWidth - 18;
  float homeButtonX = reconnectButtonX - homeButtonWidth - 10;
  float reconnectButtonY = 13;
  float tabAreaWidth = homeButtonX - 12;
  float tabWidth = tabAreaWidth / 3.0;

  if (isPointInRect(px, py, homeButtonX, reconnectButtonY, homeButtonWidth, reconnectButtonHeight)) {
    if (sendRobotHomeCommand()) {
      homeButtonHoldActive = true;
    }
    return true;
  }

  if (isPointInRect(px, py, reconnectButtonX, reconnectButtonY, reconnectButtonWidth, reconnectButtonHeight)) {
    if (!bridgeReconnectInProgress) {
      requestRobotBridgeReconnect();
    }
    return true;
  }

  if (py >= 0 && py <= headerHeight && px >= 0 && px <= tabAreaWidth) {
    if (px < tabWidth) {
      menus = 0;
    } else if (px < 2 * tabWidth) {
      menus = 1;
    } else {
      menus = 2;
    }
    clearMgiActiveField();
    return true;
  }

  return false;
}

void keyPressed() {
  if (menus == 1) {
    handleMgiKeyPressed();
  }
}

boolean isPointInRect(float px, float py, float x, float y, float w, float h) {
  return px >= x && px <= x + w && py >= y && py <= y + h;
}
