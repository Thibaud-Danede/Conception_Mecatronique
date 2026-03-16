// Variables pour le mode Cartésien (MGI)
float[] cartesian = {300, 0, 200, 180, 0, 0}; // X, Y, Z, Roll, Pitch, Yaw
String[] cartNames = {"X (mm)", "Y (mm)", "Z (mm)", "Roll (°)", "Pitch (°)", "Yaw (°)"};

void draw_menus_2() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float pannelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;

  // Titre spécifique MGI
  fill(255);
  textSize(constrain(width/40, 18, 28));

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;
    float x = marginX + (col * (pannelWidth + marginX));
    float y = marginY + (row * spacingV);
    
    // On adapte les bornes : +/- 500mm pour X,Y,Z et +/- 180° pour R,P,Y
    float minVal = (i < 3) ? -600 : -180;
    float maxVal = (i < 3) ? 600 : 180;
    
    cartesian[i] = drawCustomSlider(x, y, pannelWidth, cartNames[i], cartesian[i], minVal, maxVal);
  }
}
