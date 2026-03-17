import java.util.ArrayList;
import processing.event.MouseEvent;

// ============================================================================
// Vue 3D partagee entre plusieurs onglets.
// Cette vue ne parle pas directement au robot: elle lit seulement l'etat global
// expose par les autres fichiers, puis rend un assemblage OBJ dans un buffer P3D.
//
// Chaine d'appel principale:
// - setupRobot3DView() charge les meshes au demarrage
// - beginRobot3DFrame() reinitialise le flag de visibilite a chaque frame
// - drawRobot3DPanel() choisit la pose source et dessine la carte UI
// - renderRobot3DToBuffer() effectue le rendu 3D dans un buffer hors ecran
// - handleRobot3DMouseDrag()/handleRobot3DMouseWheel() pilotent la camera
// ============================================================================

// Liste des segments OBJ qui composent le robot.
ArrayList<Robot3DSegment> robot3dSegments = new ArrayList<Robot3DSegment>();
PGraphics robot3dBuffer = null;

// Camera utilisateur.
float robot3dRotX = -0.35;
float robot3dRotY = 0.55;
float robot3dZoom = 200;

// Etat de la vue 3D interactive.
boolean robot3dLoaded = false;
boolean robot3dDragActive = false;
float robot3dLastMouseX = 0;
float robot3dLastMouseY = 0;

float robot3dPanelX = 0;
float robot3dPanelY = 0;
float robot3dPanelW = 0;
float robot3dPanelH = 0;
boolean robot3dPanelVisible = false;
int robot3dLastRenderMs = -1000;
int robot3dRenderIntervalMs = 33;

// Valeurs lissees affichees a l'ecran pour eviter les a-coups.
float[] robot3dDisplayJoints = {0, 0, 0, 0, 0, 0};

// Offsets d'assemblage des 6 meshes OBJ du robot.
float[][] robot3dAssemblyConfig = {
  { 0.000,  0.000,  0.000,   0,  0,   0 },
  { 0.000, -0.101,  0.010,  90,  0,   0 },
  { 0.005, -0.085,  0.034, -90,  0,   0 },
  {-0.307, -0.012,  0.032,   0,  0, -66 },
  { 0.051, -0.23,   0.034,   1,  0,   0 },
  {-0.017, -0.069,  0.002, -13, 90,  24 }
};

// Charge les meshes et reinitialise la posture de rendu.
void setupRobot3DView() {
  robot3dSegments.clear();
  // L'ordre des segments doit rester aligne avec robot3dAssemblyConfig[] et avec
  // les 6 articulations du robot, car renderRobot3DToBuffer() les parcourt en serie.
  robot3dSegments.add(new Robot3DSegment(sketchPath("sketch_3d_visualisation/1.obj"), color(150), 'Y'));
  robot3dSegments.add(new Robot3DSegment(sketchPath("sketch_3d_visualisation/2.obj"), color(200), 'Z'));
  robot3dSegments.add(new Robot3DSegment(sketchPath("sketch_3d_visualisation/3.obj"), color(180), 'Z'));
  robot3dSegments.add(new Robot3DSegment(sketchPath("sketch_3d_visualisation/4.obj"), color(160), 'Z'));
  robot3dSegments.add(new Robot3DSegment(sketchPath("sketch_3d_visualisation/5.obj"), color(200), 'Y'));
  robot3dSegments.add(new Robot3DSegment(sketchPath("sketch_3d_visualisation/6.obj"), color(180), 'Z'));

  robot3dLoaded = true;
  for (int i = 0; i < robot3dDisplayJoints.length; i++) {
    robot3dDisplayJoints[i] = 0;
  }
}

// Remis a faux au debut de chaque frame; passe a vrai seulement si un panneau 3D est dessine.
void beginRobot3DFrame() {
  robot3dPanelVisible = false;
}

// Carte 3D reutilisee dans les onglets MGD, MGI et manuel.
void drawRobot3DPanel(float x, float y, float w, float h, String label) {
  robot3dPanelVisible = true;
  robot3dPanelX = x;
  robot3dPanelY = y;
  robot3dPanelW = w;
  robot3dPanelH = h;

  noStroke();
  fill(32, 36, 44, 220);
  rect(x, y, w, h, 12);

  fill(230);
  textSize(12);
  textAlign(LEFT, TOP);
  text(label, x + 12, y + 10);

  if (!robot3dLoaded) {
    fill(220, 140, 140);
    text("3D models not loaded.", x + 12, y + 30);
    textAlign(LEFT, CENTER);
    return;
  }

  // La vue affiche la pose live si elle existe, sinon les consignes locales.
  boolean useLivePose = hasLiveRobotPose;
  float[] sourceJoints = useLivePose ? liveJoints : joints;
  for (int i = 0; i < 6; i++) {
    // Les valeurs sont d'abord remappees puis lissees pour eviter des sauts
    // visuels trop secs a chaque nouvelle telemetrie.
    float mappedJoint = mapJointForRobot3D(i, sourceJoints[i], useLivePose);
    robot3dDisplayJoints[i] = lerp(robot3dDisplayJoints[i], mappedJoint, 0.20);
  }

  int viewportX = int(x + 8);
  int viewportY = int(y + 30);
  int viewportW = int(max(80, w - 16));
  int viewportH = int(max(70, h - 38));
  updateRobot3DBuffer(viewportW, viewportH);
  if (robot3dBuffer != null && millis() - robot3dLastRenderMs >= robot3dRenderIntervalMs) {
    // Le rendu 3D peut etre cadence independamment du draw() principal.
    renderRobot3DToBuffer();
    robot3dLastRenderMs = millis();
  }
  image(robot3dBuffer, viewportX, viewportY, viewportW, viewportH);

  boolean overPanel = isPointInRect(mouseX, mouseY, x, y, w, h);
  if (overPanel) {
    cursor(HAND);
  }

  fill(170);
  textSize(10);
  textAlign(LEFT, BOTTOM);
  text("Drag: rotate | Wheel: zoom", x + 12, y + h - 8);
  textAlign(LEFT, CENTER);
}

// Recale les angles live du robot sur l'orientation attendue par les meshes.
float mapJointForRobot3D(int jointIndex, float rawJoint, boolean isLivePose) {
  if (!isLivePose) {
    // Les consignes locales sont deja dans la convention attendue par la vue.
    return rawJoint;
  }

  // La telemetrie live peut utiliser une convention differente (signe/zero),
  // d'ou l'application des coeffs de calibration declaratifs du Config.pde.
  float sign = 1.0;
  float offset = 0.0;
  if (jointIndex >= 0 && jointIndex < robot3d_joint_sign.length) {
    sign = robot3d_joint_sign[jointIndex];
  }
  if (jointIndex >= 0 && jointIndex < robot3d_joint_offset_deg.length) {
    offset = robot3d_joint_offset_deg[jointIndex];
  }
  return (rawJoint + offset) * sign;
}

// Realloue le buffer hors ecran seulement si la taille du panneau change.
void updateRobot3DBuffer(int targetW, int targetH) {
  if (robot3dBuffer != null && robot3dBuffer.width == targetW && robot3dBuffer.height == targetH) {
    return;
  }

  robot3dBuffer = createGraphics(targetW, targetH, P3D);
  robot3dLastRenderMs = -1000;
}

// Dessine toute la scene 3D dans un buffer separe pour garder une UI 2D simple.
void renderRobot3DToBuffer() {
  if (robot3dBuffer == null) {
    return;
  }

  robot3dBuffer.beginDraw();
  robot3dBuffer.background(20, 22, 28);
  robot3dBuffer.noStroke();
  robot3dBuffer.lights();
  robot3dBuffer.directionalLight(190, 190, 190, -0.4, -0.9, -0.4);
  robot3dBuffer.ambientLight(70, 70, 70);
  robot3dBuffer.perspective(PI / 3.0, (float)robot3dBuffer.width / max(1.0, (float)robot3dBuffer.height), 0.001, 1000.0);

  robot3dBuffer.pushMatrix();
  robot3dBuffer.translate(robot3dBuffer.width * 0.50, robot3dBuffer.height * 0.84, 0);
  robot3dBuffer.rotateX(robot3dRotX);
  robot3dBuffer.rotateY(robot3dRotY);
  robot3dBuffer.scale(robot3dZoom);

  for (int i = 0; i < robot3dSegments.size() && i < 6; i++) {
    Robot3DSegment segment = robot3dSegments.get(i);

    // Chaque segment est pose relativement au precedent dans la pile de matrices.
    // On applique donc successivement:
    // - la translation d'assemblage
    // - la rotation fixe d'assemblage
    // - la rotation moteur dynamique de l'articulation courante
    robot3dBuffer.translate(robot3dAssemblyConfig[i][0], robot3dAssemblyConfig[i][1], robot3dAssemblyConfig[i][2]);
    robot3dBuffer.rotateX(radians(robot3dAssemblyConfig[i][3]));
    robot3dBuffer.rotateY(radians(robot3dAssemblyConfig[i][4]));
    robot3dBuffer.rotateZ(radians(robot3dAssemblyConfig[i][5]));

    segment.applyMotorRotation(robot3dBuffer, robot3dDisplayJoints[i]);
    segment.drawSegment(robot3dBuffer);
  }

  robot3dBuffer.popMatrix();
  robot3dBuffer.endDraw();
}

// Rotation orbitale de la camera au drag.
void handleRobot3DMouseDrag() {
  if (!robot3dPanelVisible) {
    return;
  }

  boolean overPanel = isPointInRect(mouseX, mouseY, robot3dPanelX, robot3dPanelY, robot3dPanelW, robot3dPanelH);
  if (!mousePressed) {
    robot3dDragActive = false;
    return;
  }

  if (!overPanel) {
    robot3dDragActive = false;
    return;
  }

  if (!robot3dDragActive) {
    // La premiere frame du drag sert juste a memoriser la reference souris.
    robot3dDragActive = true;
    robot3dLastMouseX = mouseX;
    robot3dLastMouseY = mouseY;
  }

  if (!robot3dDragActive) {
    return;
  }

  float dx = mouseX - robot3dLastMouseX;
  float dy = mouseY - robot3dLastMouseY;
  robot3dRotY += dx * 0.012;
  robot3dRotX -= dy * 0.012;
  robot3dRotX = constrain(robot3dRotX, -1.5, 1.5);
  robot3dLastMouseX = mouseX;
  robot3dLastMouseY = mouseY;
}

// Zoom a la molette quand la souris est au-dessus du panneau 3D.
void handleRobot3DMouseWheel(MouseEvent event) {
  if (!robot3dPanelVisible) {
    return;
  }

  if (!isPointInRect(mouseX, mouseY, robot3dPanelX, robot3dPanelY, robot3dPanelW, robot3dPanelH)) {
    return;
  }

  robot3dZoom -= event.getCount() * 5.0;
  robot3dZoom = constrain(robot3dZoom, 100, 2600);
}

// Objet utilitaire qui sait dessiner un mesh et lui appliquer sa rotation moteur.
class Robot3DSegment {
  PShape shapeData;
  color segmentColor;
  char motorAxis;

  Robot3DSegment(String objPath, color c, char axis) {
    shapeData = loadShape(objPath);
    segmentColor = c;
    motorAxis = axis;
    if (shapeData != null) {
      // On ignore les styles embarques dans les OBJ pour garder une palette uniforme.
      shapeData.disableStyle();
    }
  }

  // Choisit l'axe de rotation principal du segment courant.
  void applyMotorRotation(PGraphics pg, float angleDegrees) {
    float angleRad = radians(angleDegrees);
    if (motorAxis == 'X') {
      pg.rotateX(angleRad);
    } else if (motorAxis == 'Y') {
      pg.rotateY(angleRad);
    } else if (motorAxis == 'Z') {
      pg.rotateZ(angleRad);
    }
  }

  // Dessin du mesh brut avec une couleur uniforme.
  void drawSegment(PGraphics pg) {
    if (shapeData == null) {
      return;
    }

    pg.fill(segmentColor);
    pg.stroke(255, 36);
    pg.strokeWeight(0.0006);
    pg.shape(shapeData);
  }
}
