void draw_menus_3() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float panelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;

  fill(255);
  textSize(constrain(width / 40, 18, 28));
  text("CONTROL MANUELLE", marginX, marginY - 42);

  fill(160);
  textSize(12);
  text("Capteur de force sur " + forceSensorComPort + " avec tare, reconnexion serie et pilotage traction/pression en Z outil.", marginX, marginY - 16);

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;

    float x = marginX + (col * (panelWidth + marginX));
    float y = marginY + (row * spacingV);

    joints[i] = drawCustomSlider(x, y, panelWidth, names[i], joints[i], joint_min[i], joint_max[i], true);
  }

  float sensorCardY = marginY + (3 * spacingV) + 8;
  float sensorCardHeight = constrain(height * 0.28, 165, 195);
  float bottomWidth = width - (2 * marginX);
  float cardGap = 14;
  float sensorCardWidth = bottomWidth * 0.58;
  float vizCardWidth = bottomWidth - sensorCardWidth - cardGap;

  drawForceSensorCard(marginX, sensorCardY, sensorCardWidth, sensorCardHeight);
  drawRobot3DPanel(marginX + sensorCardWidth + cardGap, sensorCardY, vizCardWidth, sensorCardHeight, "3D robot preview (manual)");
}
