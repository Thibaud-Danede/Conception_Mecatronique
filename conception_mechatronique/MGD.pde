// ============================================================================
// Onglet MGD (Modele Geometrique Direct).
// Cet ecran travaille en espace articulaire:
// - les sliders manipulent directement J1..J6
// - la telemetrie live est recopied dans "joints" quand on ne drag pas
// - une seule commande est envoyee au relachement du slider
//
// Chaine d'appel principale:
// draw_menus_1() -> drawJointControlSlider() pour chaque axe
//                -> drawRobot3DPanel() pour la preview
//                -> handleMgdSliderRelease() pour l'envoi final
// ============================================================================

// Etat du slider actuellement en train d'etre glisse.
boolean mgdSliderDragActive = false;
boolean mgdSliderHadChange = false;
int mgdActiveSliderIndex = -1;

// Onglet MGD: pilotage direct en espace articulaire.
void draw_menus_1() {
  float marginX = width * 0.05;
  float marginY = height * 0.15;
  float panelWidth = (width - (3 * marginX)) / 2;
  float spacingV = height * 0.12;
  float subtitleY = marginY - 22;
  float controlsStartY = marginY + 22;

  // Hors interaction utilisateur, on recopie les valeurs live pour garder l'IHM synchronisee.
  if (hasLiveRobotPose && !mgdSliderDragActive) {
    arrayCopy(liveJoints, joints);
  }

  fill(255);
  textSize(constrain(width / 40.0, 17, 27));
  text("MGD - joint target", marginX, marginY - 45);

  fill(150);
  textSize(constrain(width / 105.0, 10, 13));
  textAlign(LEFT, TOP);
  if (hasLiveRobotPose) {
    fill(0, 255, 100); 
  } else {
    fill(255, 80, 80);  
  }

  text(
    hasLiveRobotPose
    ? "Connected: Drag a slider to send targets to the robot."
    : "Offline mode: Sliders move locally only.",
    marginX,
    subtitleY,
    width - (2 * marginX),
    32
    );

  fill(150);
  textAlign(LEFT, CENTER);

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;

    float x = marginX + (col * (panelWidth + marginX));
    float y = controlsStartY + (row * spacingV);

    // Chaque slider modifie uniquement l'etat local. L'envoi bridge est
    // volontairement differe au relachement pour eviter un flux de commandes
    // dense pendant le drag.
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

  // La preview 3D reutilise le meme tableau "joints" que les sliders.
  float vizX = marginX;
  float vizY = controlsStartY + (3 * spacingV) + 34;
  float vizW = constrain(width * 0.78, 360, 820);
  vizX = (width - vizW) * 0.5;
  float vizBottom = height - 44;
  vizY = min(vizY, vizBottom - 90);
  float vizH = vizBottom - vizY;
  vizH = constrain(vizH, 120, 340);
  drawRobot3DPanel(vizX, vizY, vizW, vizH, "3D robot preview (joint space)");

  // Ce test doit rester en fin de frame car il depend de l'etat du drag
  // accumule pendant les appels drawJointControlSlider().
  handleMgdSliderRelease();
}

// Slider specialise MGD: affiche la position reelle et ne pousse la commande qu'au relachement.
float drawJointControlSlider(int index, float x, float y, float w, String label, float val, float min, float max) {
  boolean isOverSlider = mouseX > x && mouseX < x + w && mouseY > y - 20 && mouseY < y + 30;

  if (mousePressed && isOverSlider && (!mgdSliderDragActive || mgdActiveSliderIndex == index)) {
    if (!mgdSliderDragActive) {
      // Le premier slider saisi devient "owner" du drag jusqu'au relachement.
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
    // Le trait vert montre la position reelle du robot a cote de la consigne locale.
    float actualX = map(liveJoints[index], min, max, x, x + w);
    stroke(0, 255, 150);
    strokeWeight(2);
    line(actualX, y - 6, actualX, y + 26);
  }

  float knobX = map(val, min, max, x, x + w);
  fill(0, 120, 250);
  noStroke();
  ellipse(knobX, y + 10, 20, 20);

  fill(200);
  textSize(constrain(width/70, 12, 16));
  text(label, x, y - 15);

  fill(0, 120, 250);
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

// Envoie une seule commande quand le drag se termine, pour eviter de saturer le bridge.
void handleMgdSliderRelease() {
  if (!mgdSliderDragActive || mousePressed) {
    return;
  }

  // Une fois la souris relachee, on decide quoi faire de la derniere consigne:
  // - robot live disponible -> envoi reel
  // - mode hors ligne -> simple feedback utilisateur
  if (mgdSliderHadChange && hasLiveRobotPose) {
    sendRobotJointCommand(joints);
  } else if (mgdSliderHadChange) {
    bridgeCommandStatus = "offline preview only";
  }

  mgdSliderDragActive = false;
  mgdSliderHadChange = false;
  mgdActiveSliderIndex = -1;
}

// Slider graphique reutilisable par plusieurs onglets.
float drawCustomSlider(float x, float y, float w, String label, float val, float min, float max, boolean interactive) {
  stroke(60);
  strokeWeight(3);
  line(x, y + 10, x + w, y + 10);

  if (interactive && mousePressed && mouseX > x && mouseX < x + w && mouseY > y - 20 && mouseY < y + 30) {
    val = map(mouseX, x, x + w, min, max);
  }

  float knobX = map(val, min, max, x, x + w);
  fill(0, 120, 250);
  noStroke();
  ellipse(knobX, y + 10, 20, 20);

  fill(200);
  textSize(constrain(width/70, 12, 16));
  text(label, x, y - 15);

  fill(hasLiveRobotPose ? color(0, 255, 150) : color(0, 120, 250));
  textAlign(RIGHT, CENTER);
  text(nf(val, 1, 1), x + w, y - 15);
  textAlign(LEFT, CENTER);

  return val;
}
