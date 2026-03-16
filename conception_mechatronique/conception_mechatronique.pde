float[] joints = {0, 0, 0, 0, 0, 0}; 
String[] names = {"J1: Base", "J2: Épaule", "J3: Coude", "J4: Poignet 1", "J5: Poignet 2", "J6: Poignet 3"};
int menus = 0;

void setup() {
  // Utilisez 'surface.setResizable(true)' pour tester le responsive en direct
  size(900, 600);
  surface.setResizable(true);
  textAlign(LEFT, CENTER);
}

void draw() {
  background(25);
  
  // Affichage de la barre de navigation
  drawHeader();
  
  // Affichage du menu sélectionné
  if (menus == 0) {
    draw_menus_1(); // [cite: 6]
  } else if (menus == 1) {
    draw_menus_2(); 
  } else if (menus == 2) {
    draw_menus_3();
  }
  
  drawFooter(); // [cite: 4]
}

void drawHeader() {
  noStroke();
  fill(40);
  rect(0, 0, width, 60); // Fond de la barre
  
  // On divise la barre en deux pour les onglets
  drawTab(0, 0, width/3, 60, "MODÈLE GÉOMÉTRIQUE DIRECT (MGD)", 0);
  drawTab(width/3, 0, width/3, 60, "MODÈLE GÉOMÉTRIQUE INVERSE (MGI)", 1);
  drawTab(2*width/3, 0, width/3, 60, "CONTROL MANUELLE", 2);
  // Ligne de séparation basse
  stroke(0, 120, 255);
  strokeWeight(2);
  line(0, 60, width, 60);
}

void drawTab(float x, float y, float w, float h, String label, int id) {
  // Détection du survol ou de la sélection
  boolean isSelected = (menus == id);
  boolean isHover = (mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h);
  
  if (isSelected) {
    fill(60); // Fond plus clair pour l'onglet actif
  } else if (isHover) {
    fill(50); // Fond légèrement éclairé au survol
    cursor(HAND);
  } else {
    fill(40);
    cursor(ARROW);
  }
  
  rect(x, y, w, h);
  
  // Texte de l'onglet
  textAlign(CENTER, CENTER);
  textSize(14);
  if (isSelected) {
    fill(0, 255, 150); // Texte vert/cyan si actif 
    // Petite barre de soulignement pour le style
    rect(x + 20, y + h - 5, w - 40, 3);
  } else {
    fill(200);
  }
  text(label, x + w/2, y + h/2);
  
  // Interaction clic
  if (isHover && mousePressed) {
    menus = id;
  }
  
  textAlign(LEFT, CENTER); // Reset pour le reste de l'interface 
}



void drawFooter() {
  // Barre de statut en bas
  fill(40);
  noStroke();
  rect(0, height - 40, width, 40);
  
  fill(150);
  textSize(12);
  text("Connecté au contrôleur xArm : 192.168.1.196 | Mode : SERVO_ANGLE", 20, height - 20);
}
