boolean mgdSliderDragActive = false;
boolean mgdSliderHadChange = false;
int mgdActiveSliderIndex = -1;

void draw_menus_1() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float panelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;
  float subtitleY = marginY - 22;
  float controlsStartY = marginY + 22;

  if (hasLiveRobotPose && !mgdSliderDragActive) {
    arrayCopy(liveJoints, joints);
  }

  fill(255);
  textSize(constrain(width / 40.0, 17, 27));
  text("MGD - joint target", marginX, marginY - 45);

  fill(150);
  textSize(constrain(width / 105.0, 10, 13));
  textAlign(LEFT, TOP);
  text(
    hasLiveRobotPose
      ? "Drag a slider, then release to send the joint target to the robot."
      : "Offline mode: sliders move locally only.",
    marginX,
    subtitleY,
    width - (2 * marginX),
    32
  );
  textAlign(LEFT, CENTER);

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;

    float x = marginX + (col * (panelWidth + marginX));
    float y = controlsStartY + (row * spacingV);

    joints[i] = drawJointControlSlider(
      i,
      x,
      y,
      panelWidth,
      names[i],
      joints[i],
      joint_min[i],
      joint_max[i]
    );
  }

  float vizX = marginX;
  float vizY = controlsStartY + (3 * spacingV) + 34;
  float vizW = constrain(width * 0.78, 360, 820);
  vizX = (width - vizW) * 0.5;
  float vizBottom = height - 44;
  vizY = min(vizY, vizBottom - 90);
  float vizH = vizBottom - vizY;
  vizH = constrain(vizH, 120, 340);
  drawRobot3DPanel(vizX, vizY, vizW, vizH, "3D robot preview (joint space)");

  handleMgdSliderRelease();
}

float drawJointControlSlider(int index, float x, float y, float w, String label, float val, float min, float max) {
  boolean isOverSlider = mouseX > x && mouseX < x + w && mouseY > y - 20 && mouseY < y + 30;

  if (mousePressed && isOverSlider && (!mgdSliderDragActive || mgdActiveSliderIndex == index)) {
    if (!mgdSliderDragActive) {
      mgdSliderDragActive = true;
      mgdActiveSliderIndex = index;
      mgdSliderHadChange = false;
    }

    float newValue = map(mouseX, x, x + w, min, max);
    if (abs(newValue - val) > 0.05) {
      mgdSliderHadChange = true;
      val = newValue;
    }
  }

  stroke(60);
  strokeWeight(3);
  line(x, y + 10, x + w, y + 10);

  if (hasLiveRobotPose) {
    float actualX = map(liveJoints[index], min, max, x, x + w);
    stroke(0, 255, 150);
    strokeWeight(2);
    line(actualX, y - 6, actualX, y + 26);
  }

  float knobX = map(val, min, max, x, x + w);
  fill(255, 150, 0);
  noStroke();
  ellipse(knobX, y + 10, 20, 20);

  fill(200);
  textSize(constrain(width/70, 12, 16));
  text(label, x, y - 15);

  fill(255, 150, 0);
  textAlign(RIGHT, CENTER);
  text(nf(val, 1, 1), x + w, y - 15);

  if (hasLiveRobotPose) {
    fill(0, 255, 150);
    textAlign(LEFT, CENTER);
    text("real " + nf(liveJoints[index], 1, 1), x, y + 34);
  }

  textAlign(LEFT, CENTER);
  return val;
}

void handleMgdSliderRelease() {
  if (!mgdSliderDragActive || mousePressed) {
    return;
  }

  if (mgdSliderHadChange && hasLiveRobotPose) {
    sendRobotJointCommand(joints);
  } else if (mgdSliderHadChange) {
    bridgeCommandStatus = "offline preview only";
  }

  mgdSliderDragActive = false;
  mgdSliderHadChange = false;
  mgdActiveSliderIndex = -1;
}

float drawCustomSlider(float x, float y, float w, String label, float val, float min, float max, boolean interactive) {
  stroke(60);
  strokeWeight(3);
  line(x, y + 10, x + w, y + 10);

  if (interactive && mousePressed && mouseX > x && mouseX < x + w && mouseY > y - 20 && mouseY < y + 30) {
    val = map(mouseX, x, x + w, min, max);
  }

  float knobX = map(val, min, max, x, x + w);
  fill(255, 150, 0);
  noStroke();
  ellipse(knobX, y + 10, 20, 20);

  fill(200);
  textSize(constrain(width/70, 12, 16));
  text(label, x, y - 15);

  fill(hasLiveRobotPose ? color(0, 255, 150) : color(255, 150, 0));
  textAlign(RIGHT, CENTER);
  text(nf(val, 1, 1), x + w, y - 15);
  textAlign(LEFT, CENTER);

  return val;
}
