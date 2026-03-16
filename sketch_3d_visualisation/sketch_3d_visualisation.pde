ArrayList<Segment> robot = new ArrayList<Segment>();
float rotX = 0, rotY = 0, zoom = 0.5;
float[] angles = new float[8];

void setup() {
  size(1000, 800, P3D);
  
  // ICI : On définit les distances ENTRE les axes des moteurs.
  // offsetX, offsetY, offsetZ est la position du moteur SUIVANT par rapport au moteur PRÉCÉDENT.
  
  // Exemple (à ajuster selon tes mesures CAO) :
  robot.add(new Segment("1.obj", 100, 100, 100, 0, 0, 0, 'Y'));    // Base
  robot.add(new Segment("2.obj", 200, 150, 200, 0, 0, 0, 'X'));  // J2 est à 50mm au dessus de J1
  robot.add(new Segment("3.obj", 150, 150, 150, 0, 0, 0, 'X')); // J3 est à 100mm au dessus de J2
  robot.add(new Segment("31.obj", 150, 150, 150, 0, 0, 0, 'Y'));   // Si même axe, offset = 0
  robot.add(new Segment("4.obj", 150, 150, 100, 0, 0, 0, 'X')); 
  robot.add(new Segment("5.obj", 100, 150, 100, 0, 0, 0, 'X')); 
  robot.add(new Segment("6.obj", 150, 100, 100, 0, 0, 0, 'X')); 
  robot.add(new Segment("61.obj", 150, 150, 150, 0, 0, 0, 'Y'));
}

void draw() {
  background(35);
  setupCamera();
  lights();
  
  translate(width/2, height/2 + 200, 0); 
  rotateX(rotX);
  rotateY(rotY);
  scale(zoom); 

  // --- DESSIN HIÉRARCHIQUE ---
  for (int i = 0; i < robot.size(); i++) {
    Segment s = robot.get(i);
    
    // 1. On se déplace vers l'axe du moteur actuel
    translate(s.offX, s.offY, s.offZ);
    
    // 2. On applique la rotation autour de cet axe précis
    s.appliquerRotation(angles[i]);
    
    // 3. On dessine la pièce (SANS la recentrer)
    s.dessiner();
  }
}

class Segment {
  PShape forme;
  float offX, offY, offZ;
  char axe;
  color col;

  Segment(String fichier, int r, int g, int b, float x, float y, float z, char _axe) {
    forme = loadShape(fichier);
    if (forme != null) {
      forme.disableStyle();
    }
    offX = x; offY = y; offZ = z;
    axe = _axe;
    col = color(r, g, b);
  }

  void appliquerRotation(float a) {
    if (axe == 'Y') rotateY(radians(a));
    else if (axe == 'X') rotateX(radians(a));
    else if (axe == 'Z') rotateZ(radians(a));
  }

  void dessiner() {
    if (forme != null) {
      // TRÈS IMPORTANT : On ne fait plus de translate() ici. 
      // On dessine l'objet tel qu'il a été conçu par rapport à son origine (0,0,0).
      fill(col);
      stroke(255, 40);
      shape(forme);
    }
  }
}

// ... (reste des fonctions mouseDragged, setupCamera etc. identiques)
void setupCamera() {
  float cameraZ = (height/2.0) / tan(PI*30.0 / 180.0);
  // Augmentation du Z-far pour ne pas que le bras disparaisse
  perspective(PI/3.0, (float)width/height, cameraZ/100.0, cameraZ*1000.0);
}

void mouseDragged() {
  rotY += (mouseX - pmouseX) * 0.01;
  rotX -= (mouseY - pmouseY) * 0.01;
}

void mouseWheel(MouseEvent event) {
  zoom -= event.getCount() * 0.05;
  zoom = constrain(zoom, 0.01, 10.0);
}

void keyPressed() {
  // Contrôle rapide : Touches 1-8 pour augmenter, AZERTY... pour diminuer
  if (key == '1') angles[0] += 2; if (key == 'a') angles[0] -= 2;
  if (key == '2') angles[1] += 2; if (key == 'z') angles[1] -= 2;
  if (key == '3') angles[2] += 2; if (key == 'e') angles[2] -= 2;
  if (key == '4') angles[3] += 2; if (key == 'r') angles[3] -= 2;
  if (key == '5') angles[4] += 2; if (key == 't') angles[4] -= 2;
  if (key == '6') angles[5] += 2; if (key == 'y') angles[5] -= 2;
}
