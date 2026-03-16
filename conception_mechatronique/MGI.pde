float[] cartesian = {300, 0, 200, 180, 0, 0};
String[] cartNames = {"X (mm)", "Y (mm)", "Z (mm)", "Roll (deg)", "Pitch (deg)", "Yaw (deg)"};

void draw_menus_2() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float panelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;
  float[] displayedCartesian = hasLiveRobotPose ? liveCartesian : cartesian;

  fill(255);
  textSize(constrain(width/40, 18, 28));

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;
    float x = marginX + (col * (panelWidth + marginX));
    float y = marginY + (row * spacingV);

    float minVal = (i < 3) ? -600 : -180;
    float maxVal = (i < 3) ? 600 : 180;

    float displayedValue = drawCustomSlider(
      x,
      y,
      panelWidth,
      cartNames[i],
      displayedCartesian[i],
      minVal,
      maxVal,
      !hasLiveRobotPose
    );

    if (!hasLiveRobotPose) {
      cartesian[i] = displayedValue;
    }
  }
}
