void draw_menus_3() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float panelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;

  fill(255);
  textSize(constrain(width/40, 18, 28));

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;

    float x = marginX + (col * (panelWidth + marginX));
    float y = marginY + (row * spacingV);

    joints[i] = drawCustomSlider(x, y, panelWidth, names[i], joints[i], joint_min[i], joint_max[i], true);
  }
}
