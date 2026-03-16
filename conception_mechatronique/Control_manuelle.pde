void draw_menus_3(){
    // Marges dynamiques
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float pannelWidth = (width - (3 * marginX)) / 2; // Calcul pour 2 colonnes
  float sliderHeight = 40;
  float spacingV = height * 0.12;

  // Titre adaptatif
  fill(255);
  textSize(constrain(width/40, 18, 28));

  // Boucle de rendu des 6 axes
  for (int i = 0; i < 6; i++) {
    // Calcul de la position en grille (2 colonnes, 3 lignes)
    int col = i / 3;
    int row = i % 3;
    
    float x = marginX + (col * (pannelWidth + marginX));
    float y = marginY + (row * spacingV);
    
    joints[i] = drawCustomSlider(x, y, pannelWidth, names[i], joints[i], joint_min[i] , joint_max[i]);
  }
}
