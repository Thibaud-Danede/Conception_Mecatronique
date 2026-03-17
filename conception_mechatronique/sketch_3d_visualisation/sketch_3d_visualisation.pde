ArrayList<Segment> robot = new ArrayList<Segment>();
float rotX_cam = 0, rotY_cam = 0, zoom = 1500; 

// --- TABLEAU DE CONFIGURATION D'ASSEMBLAGE (Fixe) ---
float[][] config = {
  { 0.000,  0.000,  0.000,   0,  0,   0 }, // J1
  { 0.000, -0.101,  0.010,  90,  0,   0 }, // J2
  { 0.005, -0.085,  0.034, -90,  0,   0 }, // J3
  {-0.307, -0.012,  0.032,   0,  0, -66 }, // J4
  { 0.051, -0.230,  0.034,   1,  0,   0 }, // J5
  {-0.017, -0.069,  0.002, -13, 90,  24 }  // J6
};

// --- TABLEAU DES ANGLES DE MOTEURS (Dynamique) ---
float[] jointAngles = new float[6]; 

void setup() {
  size(1200, 800, P3D);
  
  // ICI : Tu définis l'AXE DE ROTATION DU MOTEUR pour chaque pièce
  // (Celui qui fait bouger le bras une fois assemblé)
  robot.add(new Segment("1.obj", color(150), 'Y')); 
  robot.add(new Segment("2.obj", color(200), 'X')); 
  robot.add(new Segment("3.obj", color(180), 'X')); 
  robot.add(new Segment("4.obj", color(160), 'Z')); 
  robot.add(new Segment("5.obj", color(200), 'X')); 
  robot.add(new Segment("6.obj", color(180), 'Z')); 
  
  // Exemple de test au démarrage
  setJoints(0, 0, 0, 0, 0, 0);
}

// --- LA FONCTION QUE TU DEMANDAIS ---
// Appelle cette fonction avec 6 valeurs pour faire bouger le robot
void setJoints(float j1, float j2, float j3, float j4, float j5, float j6) {
  jointAngles[0] = j1;
  jointAngles[1] = j2;
  jointAngles[2] = j3;
  jointAngles[3] = j4;
  jointAngles[4] = j5;
  jointAngles[5] = j6;
}

void draw() {
  background(35);
  setupCamera();
  lights();
  
  // Position globale
  translate(width/2, height/2 + 200, 0); 
  rotateX(rotX_cam);
  rotateY(rotY_cam);
  scale(zoom); 

  // --- RENDU HIÉRARCHIQUE ---
  for (int i = 0; i < robot.size(); i++) {
    Segment s = robot.get(i);
    
    // 1. Placement (Shift CAO)
    translate(config[i][0], config[i][1], config[i][2]);
    
    // 2. Orientation (Shift CAO)
    rotateX(radians(config[i][3]));
    rotateY(radians(config[i][4]));
    rotateZ(radians(config[i][5]));
    
    // 3. Rotation du Moteur (Dynamique)
    // On tourne autour de l'axe moteur défini dans le setup
    s.appliquerRotationMoteur(jointAngles[i]);
    
    // 4. Dessin
    s.dessiner();
  }
}

class Segment {
  PShape forme;
  color col;
  char axeMoteur;

  Segment(String fichier, color c, char am) {
    forme = loadShape(fichier);
    col = c;
    axeMoteur = am;
    if (forme != null) forme.disableStyle();
  }

  void appliquerRotationMoteur(float angle) {
    float r = radians(angle);
    if (axeMoteur == 'X') rotateX(r);
    else if (axeMoteur == 'Y') rotateY(r);
    else if (axeMoteur == 'Z') rotateZ(r);
  }

  void dessiner() {
    if (forme != null) {
      fill(col);
      stroke(255, 40);
      strokeWeight(0.0005); 
      shape(forme);
      // Pivot visuel
      stroke(255, 255, 0); strokeWeight(0.01); point(0,0,0);
    }
  }
}

// --- CONTROLES CLAVIER POUR TESTER ---
void keyPressed() {
  if (key == 'q') jointAngles[0] += 2; if (key == 'a') jointAngles[0] -= 2;
  if (key == 'w') jointAngles[1] += 2; if (key == 's') jointAngles[1] -= 2;
  if (key == 'e') jointAngles[2] += 2; if (key == 'd') jointAngles[2] -= 2;
  if (key == 'r') jointAngles[3] += 2; if (key == 'f') jointAngles[3] -= 2;
  if (key == 't') jointAngles[4] += 2; if (key == 'g') jointAngles[4] -= 2;
  if (key == 'y') jointAngles[5] += 2; if (key == 'h') jointAngles[5] -= 2;
}

void setupCamera() { perspective(PI/3.0, (float)width/height, 0.001, 1000.0); }
void mouseDragged() { rotY_cam += (mouseX - pmouseX) * 0.01; rotX_cam -= (mouseY - pmouseY) * 0.01; }
void mouseWheel(MouseEvent event) { zoom -= event.getCount() * 100; }
