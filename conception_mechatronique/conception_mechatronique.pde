import java.io.File;
import processing.serial.*;
import processing.event.MouseEvent;

// ============================================================================
// Fichier principal du sketch Processing.
// - Centralise l'etat partage entre les onglets.
// - Orchestre la boucle frame par frame.
// - Redirige ensuite le travail vers les sous-modules:
//   * RobotBridge.pde pour la communication avec le bridge C#
//   * ForceSensor.pde pour le capteur serie et l'auto-nudge
//   * MGD.pde / MGI.pde / Control_manuelle.pde pour les ecrans
//   * Robot3DView.pde pour le rendu 3D commun
//
// Cycle d'une frame:
// 1. draw() met a jour le bridge robot
// 2. draw() met a jour le capteur de force
// 3. draw() reinitialise l'etat "panneau 3D visible"
// 4. draw() dessine le header
// 5. draw() delegue au bon onglet selon "menus"
// 6. draw() dessine le footer
// ============================================================================

// Etat partage des articulations ciblees par l'IHM.
float[] joints = {0, 0, 0, 0, 0, 0};
String[] names = {"J1: Base", "J2: Epaule", "J3: Coude", "J4: Poignet 1", "J5: Poignet 2", "J6: Poignet 3"};

// Onglet courant: 0 = MGD, 1 = MGI, 2 = controle manuel.
int menus = 0;

// Le bouton Home reste actif tant que la souris est maintenue.
boolean homeButtonHoldActive = false;

// Point d'entree du sketch: initialise le bridge, le capteur et la vue 3D.
void setup() {
  size(900, 600, P3D);
  surface.setResizable(true);
  textAlign(LEFT, CENTER);

  // L'ordre compte peu ici, mais on initialise d'abord les sous-systemes
  // qui exposent de l'etat global, puis les ecrans qui s'appuient dessus.
  setupRobotBridge();
  setupMgiUi();
  setupForceSensor();
  // Module transverse de securite, branche apres le capteur qu'il observe.
  setupSafetyInterlocks();
  setupRobot3DView();
}

// Boucle principale: met a jour les donnees, puis dessine l'onglet actif.
void draw() {
  background(25);

  // Les donnees runtime sont rafraichies avant le dessin pour que les
  // widgets des onglets lisent toutes le meme etat coherent sur la frame.
  updateRobotBridge();
  updateForceSensor();
  // L'interlock lit la mesure capteur fraiche et peut eventuellement latche un stop.
  updateSafetyInterlocks();
  beginRobot3DFrame();
  cursor(ARROW);

  drawHeader();

  if (menus == 0) {
    draw_menus_1();
  } else if (menus == 1) {
    draw_menus_2();
  } else if (menus == 2) {
    draw_menus_3();
  }

  drawFooter();
  // L'overlay est dessine tout a la fin pour passer au-dessus de toute l'IHM.
  drawSafetyInterlockOverlay();
}

// Barre haute commune a tous les onglets.
void drawHeader() {
  float headerHeight = 60;
  float homeButtonWidth = 96;
  float reconnectButtonWidth = 132;
  float reconnectButtonHeight = 34;
  float reconnectButtonX = width - reconnectButtonWidth - 18;
  float homeButtonX = reconnectButtonX - homeButtonWidth - 10;
  float reconnectButtonY = 13;
  float tabAreaWidth = homeButtonX - 12;
  float tabWidth = tabAreaWidth / 3.0;

  noStroke();
  fill(40);
  rect(0, 0, width, headerHeight);

  drawTab(0, 0, tabWidth, headerHeight, "MODELE GEOMETRIQUE DIRECT (MGD)", 0);
  drawTab(tabWidth, 0, tabWidth, headerHeight, "MODELE GEOMETRIQUE INVERSE (MGI)", 1);
  drawTab(2 * tabWidth, 0, tabWidth, headerHeight, "CONTROL MANUELLE", 2);
  drawHomeButton(homeButtonX, reconnectButtonY, homeButtonWidth, reconnectButtonHeight);
  drawReconnectButton(reconnectButtonX, reconnectButtonY, reconnectButtonWidth, reconnectButtonHeight);

  stroke(0, 120, 255);
  strokeWeight(2);
  line(0, headerHeight, width, headerHeight);
}

// Onglet cliquable avec etat hover/selection.
void drawTab(float x, float y, float w, float h, String label, int id) {
  boolean isSelected = (menus == id);
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);

  if (isSelected) {
    fill(60);
  } else if (isHover) {
    fill(50);
    cursor(HAND);
  } else {
    fill(40);
  }

  noStroke();
  rect(x, y, w, h);

  textAlign(CENTER, CENTER);
  textSize(14);
  if (isSelected) {
    fill(0, 255, 150);
    rect(x + 20, y + h - 5, w - 40, 3);
  } else {
    fill(200);
  }
  text(label, x + w / 2, y + h / 2);

  textAlign(LEFT, CENTER);
}

// Bouton de relance du bridge local.
void drawReconnectButton(float x, float y, float w, float h) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  boolean isEnabled = !bridgeReconnectInProgress;
  int fillColor = color(54, 60, 70);
  int strokeColor = color(110, 120, 140);

  if (!isEnabled) {
    fillColor = color(56, 56, 56);
    strokeColor = color(90);
  } else if (isHover) {
    fillColor = color(0, 120, 255);
    strokeColor = color(120, 190, 255);
    cursor(HAND);
  }

  stroke(strokeColor);
  strokeWeight(1.5);
  fill(fillColor);
  rect(x, y, w, h, 10);

  fill(isEnabled ? color(240) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(bridgeReconnectInProgress ? "Reconnecting..." : "Reconnect", x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}

// Bouton Home qui envoie un mouvement maintenu tant que la souris reste appuyee.
void drawHomeButton(float x, float y, float w, float h) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  boolean isEnabled = canQueueMotionCommand() || homeButtonHoldActive;
  int fillColor = color(54, 60, 70);
  int strokeColor = color(110, 120, 140);

  if (homeButtonHoldActive) {
    fillColor = color(0, 160, 110);
    strokeColor = color(120, 220, 180);
  } else if (!isEnabled) {
    fillColor = color(56, 56, 56);
    strokeColor = color(90);
  } else if (isHover) {
    fillColor = color(0, 120, 255);
    strokeColor = color(120, 190, 255);
    cursor(HAND);
  }

  stroke(strokeColor);
  strokeWeight(1.5);
  fill(fillColor);
  rect(x, y, w, h, 10);

  fill(isEnabled ? color(240) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(homeButtonHoldActive ? "Hold Home" : "Home", x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}

// Bandeau bas avec le resume d'etat courant.
void drawFooter() {
  fill(40);
  noStroke();
  rect(0, height - 40, width, 40);

  fill(150);
  textSize(12);
  textAlign(LEFT, CENTER);
  text(ellipsizeToWidth(buildFooterStatus(), width - 44), 20, height - 20);
}

// Tronque les statuts trop longs pour qu'ils restent lisibles dans le footer.
String ellipsizeToWidth(String textValue, float maxWidth) {
  if (textValue == null) {
    return "";
  }

  if (textWidth(textValue) <= maxWidth) {
    return textValue;
  }

  String suffix = "...";
  String candidate = textValue;
  while (candidate.length() > 0 && textWidth(candidate + suffix) > maxWidth) {
    candidate = candidate.substring(0, candidate.length() - 1);
  }

  return candidate + suffix;
}

// Redirige les clics vers le header, le capteur de force ou l'onglet MGI.
void mousePressed() {
  if (isForceSafetyStopLatched()) {
    // Tant que la popup de securite est la, elle capture toute la souris.
    handleSafetyInterlockMousePressed(mouseX, mouseY);
    return;
  }

  // Priorite aux controles globaux, qui sont accessibles depuis tous les onglets.
  if (handleHeaderMousePressed(mouseX, mouseY)) {
    return;
  }

  if (menus == 2) {
    // Les clics de l'onglet manuel sont d'abord proposes a la carte capteur.
    if (handleForceSensorMousePressed(mouseX, mouseY)) {
      return;
    }
  }

  if (menus == 1) {
    // L'onglet MGI gere ses champs texte, steppers et boutons d'action.
    handleMgiMousePressed(mouseX, mouseY);
  }
}

// Relache les actions "hold" en cours.
void mouseReleased() {
  if (homeButtonHoldActive) {
    homeButtonHoldActive = false;
    sendRobotStopCommand();
  }

  handleMgiMouseReleased();
}

// Gere la navigation entre onglets et les boutons globaux du header.
boolean handleHeaderMousePressed(float px, float py) {
  float headerHeight = 60;
  float homeButtonWidth = 96;
  float reconnectButtonWidth = 132;
  float reconnectButtonHeight = 34;
  float reconnectButtonX = width - reconnectButtonWidth - 18;
  float homeButtonX = reconnectButtonX - homeButtonWidth - 10;
  float reconnectButtonY = 13;
  float tabAreaWidth = homeButtonX - 12;
  float tabWidth = tabAreaWidth / 3.0;

  // Les boutons fixes du header sont testes avant le changement d'onglet.
  if (isPointInRect(px, py, homeButtonX, reconnectButtonY, homeButtonWidth, reconnectButtonHeight)) {
    if (sendRobotHomeCommand()) {
      // Le mouvement Home reste maintenu jusqu'au mouseReleased global.
      homeButtonHoldActive = true;
    }
    return true;
  }

  if (isPointInRect(px, py, reconnectButtonX, reconnectButtonY, reconnectButtonWidth, reconnectButtonHeight)) {
    if (!bridgeReconnectInProgress) {
      requestRobotBridgeReconnect();
    }
    return true;
  }

  if (py >= 0 && py <= headerHeight && px >= 0 && px <= tabAreaWidth) {
    if (px < tabWidth) {
      menus = 0;
    } else if (px < 2 * tabWidth) {
      menus = 1;
    } else {
      menus = 2;
    }
    // On quitte proprement l'edition clavier MGI quand on change d'ecran.
    clearMgiActiveField();
    return true;
  }

  return false;
}

// Le clavier ne sert actuellement qu'a l'edition des champs MGI.
void keyPressed() {
  if (menus == 1) {
    handleMgiKeyPressed();
  }
}

// Les rotations 3D sont capturees seulement si un panneau 3D est visible.
void mouseDragged() {
  handleRobot3DMouseDrag();
}

// La molette pilote le zoom de la vue 3D.
void mouseWheel(MouseEvent event) {
  handleRobot3DMouseWheel(event);
}

// Helper geometrique reutilise partout dans l'IHM.
boolean isPointInRect(float px, float py, float x, float y, float w, float h) {
  return px >= x && px <= x + w && py >= y && py <= y + h;
}
