// ============================================================================
// Interlocks de securite transverses.
//
// Pour l'instant ce module implemente un arret de securite base sur la force:
// - actif dans tous les onglets sauf le controle manuel
// - declenche si la force mesuree depasse un seuil configurable
// - envoie un stop au robot une seule fois
// - garde ensuite un latch logiciel tant qu'un reset explicite n'a pas ete fait
//
// Ce fichier fait le lien entre:
// - ForceSensor.pde pour la mesure
// - RobotBridge.pde pour l'arret et le blocage des mouvements
// - conception_mechatronique.pde pour l'overlay popup et les interactions souris
// ============================================================================

boolean forceSafetyStopLatched = false;
// Resume humain visible dans le footer et dans la popup.
String forceSafetyStopStatus = "force safety stop idle";
String forceSafetyStopTriggerSource = "";
// On memorise a la fois la force brute et la valeur observee apres eventuel abs().
float forceSafetyStopTriggeredForceN = 0.0;
float forceSafetyStopTriggeredObservedForceN = 0.0;
int forceSafetyStopTriggeredAtMs = -1;
int forceSafetyStopLastStopSequence = -1;

// Geometrie du bouton de reset de l'overlay modal.
float forceSafetyResetBtnX = 0;
float forceSafetyResetBtnY = 0;
float forceSafetyResetBtnW = 0;
float forceSafetyResetBtnH = 0;

void setupSafetyInterlocks() {
  // Au demarrage, l'interlock est neutre mais deja arme logiquement si la config l'autorise.
  resetForceSafetyStopState("force safety stop idle");
}

void updateSafetyInterlocks() {
  // Cette fonction est appelee a chaque frame apres updateForceSensor().
  // Elle suppose donc que la mesure courante a deja ete rafraichie si le capteur est actif.
  if (!forceSafetyStopEnabled || forceSafetyStopLatched) {
    return;
  }

  // L'interlock ne doit pas se declencher dans le use case manuel.
  if (menus == 2) {
    return;
  }

  if (forceSensorPort == null || !isForceSensorFresh()) {
    return;
  }

  float rawForceN = getForceSensorValueN();
  float observedForceN = forceSafetyStopUseAbsoluteValue ? abs(rawForceN) : rawForceN;
  if (observedForceN <= max(0.0, forceSafetyStopThresholdN)) {
    return;
  }

  // Le premier depassement du seuil bascule l'interlock dans un etat latche.
  triggerForceSafetyStop(rawForceN, observedForceN);
}

void triggerForceSafetyStop(float rawForceN, float observedForceN) {
  int now = millis();
  // Une fois latche, plus aucune commande de mouvement ne doit etre acceptee
  // tant qu'un reset explicite n'a pas ete demande par l'utilisateur.
  forceSafetyStopLatched = true;
  forceSafetyStopTriggeredForceN = rawForceN;
  forceSafetyStopTriggeredObservedForceN = observedForceN;
  forceSafetyStopTriggeredAtMs = now;
  forceSafetyStopTriggerSource = getForceSafetyStopSourceLabel();
  forceSafetyStopStatus =
    "force safety stop latched at " + nf(observedForceN, 1, 2) +
    " N (threshold " + nf(forceSafetyStopThresholdN, 1, 2) + " N)";

  // On remet a zero les interactions "hold" pour que l'IHM reflete bien l'arret.
  homeButtonHoldActive = false;
  mgiSendHoldActive = false;
  mgdSliderDragActive = false;
  mgdSliderHadChange = false;
  mgdActiveSliderIndex = -1;

  // Par precaution, on coupe aussi tout etat auto-nudge derive du capteur.
  // Cela evite qu'une logique de vitesse residuelle tente de repartir juste apres le stop.
  requestForceSensorAutoNudgeStop("force safety stop latched", now);

  if (sendRobotStopCommand()) {
    // On memorise la sequence du stop pour faciliter un diagnostic futur si besoin.
    forceSafetyStopLastStopSequence = bridgeCommandSequence;
    bridgeCommandStatus = "force safety stop -> stop requested";
  } else {
    bridgeCommandStatus = "force safety stop latched, but stop command could not be queued";
  }
}

void resetForceSafetyStopLatch() {
  // Le reset ne relance rien tout seul: il retire seulement le verrou logiciel.
  // Si la force est toujours au-dessus du seuil, updateSafetyInterlocks() retriggera aussitot.
  resetForceSafetyStopState("force safety stop reset");
}

void resetForceSafetyStopState(String nextStatus) {
  // Helper commun pour centraliser tous les champs du latch.
  forceSafetyStopLatched = false;
  forceSafetyStopStatus = nextStatus;
  forceSafetyStopTriggerSource = "";
  forceSafetyStopTriggeredForceN = 0.0;
  forceSafetyStopTriggeredObservedForceN = 0.0;
  forceSafetyStopTriggeredAtMs = -1;
  forceSafetyStopLastStopSequence = -1;
}

boolean isForceSafetyStopLatched() {
  // La config peut desactiver totalement cette couche sans avoir a nettoyer l'etat.
  return forceSafetyStopEnabled && forceSafetyStopLatched;
}

String getForceSafetyStopMotionBlockReason() {
  if (!isForceSafetyStopLatched()) {
    return "";
  }

  return "force safety stop latched (" + nf(forceSafetyStopTriggeredObservedForceN, 1, 2) + " N)";
}

String getForceSafetyStopSourceLabel() {
  if (menus == 0) {
    return "MGD";
  }
  if (menus == 1) {
    return "MGI";
  }
  if (menus == 2) {
    return "CONTROL MANUELLE";
  }
  return "unknown";
}

boolean handleSafetyInterlockMousePressed(float px, float py) {
  if (!isForceSafetyStopLatched()) {
    return false;
  }

  if (isPointInRect(px, py, forceSafetyResetBtnX, forceSafetyResetBtnY, forceSafetyResetBtnW, forceSafetyResetBtnH)) {
    // Le bouton retire le verrou, mais ne renvoie pas de commande robot.
    resetForceSafetyStopLatch();
    return true;
  }

  // Tant que le popup est affiche, on bloque les autres interactions.
  return true;
}

void drawSafetyInterlockOverlay() {
  if (!isForceSafetyStopLatched()) {
    return;
  }

  // Overlay modal volontairement dessine au-dessus de toute l'IHM:
  // l'operateur doit reconnaitre le safety stop avant de reprendre la main.
  float panelW = min(width * 0.72, 620);
  float panelH = min(height * 0.42, 280);
  float panelX = (width - panelW) * 0.5;
  float panelY = (height - panelH) * 0.5 - 18;
  float contentX = panelX + 24;
  float titleY = panelY + 22;
  float line1Y = panelY + 64;
  float line2Y = panelY + 92;
  float line3Y = panelY + 120;
  float line4Y = panelY + 148;
  float buttonY = panelY + panelH - 54;

  fill(0, 170);
  noStroke();
  rect(0, 0, width, height);

  fill(38, 18, 18, 238);
  stroke(255, 120, 120);
  strokeWeight(2);
  rect(panelX, panelY, panelW, panelH, 16);

  fill(255, 120, 120);
  textAlign(LEFT, TOP);
  textSize(24);
  text("FORCE SAFETY STOP", contentX, titleY);

  fill(245);
  textSize(14);
  text("The robot was stopped because the force threshold was exceeded outside manual control.", contentX, line1Y, panelW - 48, 26);

  fill(220);
  textSize(13);
  text("Source tab: " + forceSafetyStopTriggerSource, contentX, line2Y);
  text("Measured force: " + nf(forceSafetyStopTriggeredForceN, 1, 2) + " N", contentX, line3Y);
  text("Observed threshold check: " + nf(forceSafetyStopTriggeredObservedForceN, 1, 2) + " N / limit " + nf(forceSafetyStopThresholdN, 1, 2) + " N", contentX, line4Y);

  fill(200);
  textSize(12);
  text("Reset is manual. If the force is still above threshold, the stop will trigger again.", contentX, panelY + panelH - 86, panelW - 48, 32);

  forceSafetyResetBtnW = 186;
  forceSafetyResetBtnH = 32;
  forceSafetyResetBtnX = panelX + panelW - forceSafetyResetBtnW - 24;
  forceSafetyResetBtnY = buttonY;

  // Le reset est l'unique action disponible tant que le stop est latche.
  drawSafetyInterlockButton(forceSafetyResetBtnX, forceSafetyResetBtnY, forceSafetyResetBtnW, forceSafetyResetBtnH, "Reset safety stop", true);
  textAlign(LEFT, CENTER);
}

void drawSafetyInterlockButton(float x, float y, float w, float h, String label, boolean enabled) {
  // Petit helper visuel local a l'overlay pour eviter de melanger cette UI
  // critique avec les styles plus generiques du reste du sketch.
  boolean isHover = enabled && isPointInRect(mouseX, mouseY, x, y, w, h);
  color fillColor = enabled ? color(140, 40, 40) : color(70);
  color strokeColor = enabled ? color(255, 170, 170) : color(90);

  if (isHover) {
    fillColor = color(180, 60, 60);
    cursor(HAND);
  }

  stroke(strokeColor);
  strokeWeight(1.5);
  fill(fillColor);
  rect(x, y, w, h, 10);

  fill(enabled ? color(250) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(label, x + w / 2, y + h / 2);
}
