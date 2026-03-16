
void draw_menus_1(){
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

// Une version légèrement modifiée pour accepter des bornes min/max personnalisées
float drawCustomSlider(float x, float y, float w, String label, float val, float min, float max) {
  stroke(60);
  strokeWeight(3);
  line(x, y + 10, x + w, y + 10);
  
  if (mousePressed && mouseX > x && mouseX < x + w && mouseY > y - 20 && mouseY < y + 30) {
    val = map(mouseX, x, x + w, min, max);
  }

  float knobX = map(val, min, max, x, x + w);
  fill(255, 150, 0); // Orange pour différencier du mode MGD
  noStroke();
  ellipse(knobX, y + 10, 20, 20);
  
  fill(200);
  textSize(constrain(width/70, 12, 16));
  text(label, x, y - 15);
  
  fill(255, 150, 0);
  textAlign(RIGHT, CENTER);
  text(nf(val, 1, 1), x + w, y - 15);
  textAlign(LEFT, CENTER);
  
  return val;
}
