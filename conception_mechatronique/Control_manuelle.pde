void draw_menus_3() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float panelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;
  float subtitleY = marginY - 20;
  float controlsStartY = marginY + 22;

  fill(255);
  textSize(constrain(width / 40.0, 17, 27));
  text("CONTROL MANUELLE", marginX, marginY - 42);

  fill(160);
  textSize(constrain(width / 105.0, 10, 13));
  textAlign(LEFT, TOP);
  text(
    "Capteur de force sur " + forceSensorComPort + " avec tare auto, reconnexion serie et auto-step Z optionnel.",
    marginX,
    subtitleY,
    width - (2 * marginX),
    34
  );
  textAlign(LEFT, CENTER);

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;

    float x = marginX + (col * (panelWidth + marginX));
    float y = controlsStartY + (row * spacingV);

    joints[i] = drawCustomSlider(x, y, panelWidth, names[i], joints[i], joint_min[i], joint_max[i], true);
  }

  float sensorCardY = controlsStartY + (3 * spacingV) + 8;
  float bottomLimit = height - 48;
  float availableBottomHeight = bottomLimit - sensorCardY;
  float sensorCardHeight = min(260, availableBottomHeight);
  if (sensorCardHeight < 110) {
    sensorCardHeight = 110;
    sensorCardY = bottomLimit - sensorCardHeight;
  }
  float bottomWidth = width - (2 * marginX);
  float cardGap = 14;
  boolean useStackedLayout = bottomWidth < 880;

  if (useStackedLayout) {
    float sensorH = sensorCardHeight * 0.56;
    float vizH = sensorCardHeight - sensorH - cardGap;
    if (vizH < 100) {
      vizH = 100;
      sensorH = sensorCardHeight - vizH - cardGap;
    }
    sensorH = max(95, sensorH);
    drawForceSensorCard(marginX, sensorCardY, bottomWidth, sensorH);
    float vizW = constrain(bottomWidth * 0.78, 320, 760);
    float vizX = marginX + (bottomWidth - vizW) * 0.5;
    drawRobot3DPanel(vizX, sensorCardY + sensorH + cardGap, vizW, vizH, "3D robot preview (manual)");
  } else {
    float vizCardWidth = constrain(bottomWidth * 0.34, 300, 430);
    float sensorCardWidth = bottomWidth - vizCardWidth - cardGap;
    if (sensorCardWidth < 320) {
      sensorCardWidth = 320;
      vizCardWidth = bottomWidth - sensorCardWidth - cardGap;
    }
    drawForceSensorCard(marginX, sensorCardY, sensorCardWidth, sensorCardHeight);
    drawRobot3DPanel(marginX + sensorCardWidth + cardGap, sensorCardY, vizCardWidth, sensorCardHeight, "3D robot preview (manual)");
  }
}
