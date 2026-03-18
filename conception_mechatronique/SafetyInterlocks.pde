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
float forceSafetyStopThresholdUsedN = 0.0;
boolean forceSafetyStopAutoReleaseQueued = false;
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
float forceSafetyMeasureBtnX = 0;
float forceSafetyMeasureBtnY = 0;
float forceSafetyMeasureBtnW = 0;
float forceSafetyMeasureBtnH = 0;

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
  float activeThresholdN = getActiveForceSafetyStopThresholdN();
  if (observedForceN <= activeThresholdN) {
    return;
  }

  // Le premier depassement du seuil bascule l'interlock dans un etat latche.
  triggerForceSafetyStop(rawForceN, observedForceN, activeThresholdN);
}

void triggerForceSafetyStop(float rawForceN, float observedForceN, float thresholdUsedN) {
  int now = millis();
  // Une fois latche, plus aucune commande de mouvement ne doit etre acceptee
  // tant qu'un reset explicite n'a pas ete demande par l'utilisateur.
  forceSafetyStopLatched = true;
  forceSafetyStopTriggeredForceN = rawForceN;
  forceSafetyStopTriggeredObservedForceN = observedForceN;
  forceSafetyStopThresholdUsedN = thresholdUsedN;
  forceSafetyStopTriggeredAtMs = now;
  forceSafetyStopTriggerSource = getForceSafetyStopSourceLabel();
  forceSafetyStopStatus =
    "force safety stop latched at " + nf(observedForceN, 1, 2) +
    " N (threshold " + nf(thresholdUsedN, 1, 2) + " N)";

  // On remet a zero les interactions "hold" pour que l'IHM reflete bien l'arret.
  homeButtonHoldActive = false;
  mgiSendHoldActive = false;
  mgdSliderDragActive = false;
  mgdSliderHadChange = false;
  mgdActiveSliderIndex = -1;

  boolean autoReleaseQueued = false;
  if (shouldAutoReleaseMeasureSafetyStop()) {
    // En mode mesure, on privilegie un petit degagement oppose a la force
    // plutot qu'un simple gel contre la plaque.
    resetForceSensorAutoNudgeState("force safety stop latched");
    autoReleaseQueued = queueMeasureSafetyAutoRelease(rawForceN);
  } else {
    // Hors mode mesure, on coupe toute logique derivee et on garde un stop sec.
    requestForceSensorAutoNudgeStop("force safety stop latched", now);
  }

  if (autoReleaseQueued) {
    forceSafetyStopAutoReleaseQueued = true;
    forceSafetyStopLastStopSequence = bridgeCommandSequence;
    bridgeCommandStatus = "measure safety stop -> auto release queued";
  } else if (sendRobotStopCommand()) {
    // On memorise la sequence du stop pour faciliter un diagnostic futur si besoin.
    forceSafetyStopLastStopSequence = bridgeCommandSequence;
    bridgeCommandStatus = "force safety stop -> stop requested";
  } else {
    bridgeCommandStatus = "force safety stop latched, but stop command could not be queued";
  }

  recordMoodleCsvEvent("force_safety_stop_latched");
}

void resetForceSafetyStopLatch() {
  // Le reset ne relance rien tout seul: il retire seulement le verrou logiciel.
  // Si la force est toujours au-dessus du seuil, updateSafetyInterlocks() retriggera aussitot.
  resetForceSafetyStopState("force safety stop reset");
  recordMoodleCsvEvent("force_safety_stop_reset");
}

void resetForceSafetyStopState(String nextStatus) {
  // Helper commun pour centraliser tous les champs du latch.
  forceSafetyStopLatched = false;
  forceSafetyStopStatus = nextStatus;
  forceSafetyStopTriggerSource = "";
  forceSafetyStopThresholdUsedN = 0.0;
  forceSafetyStopAutoReleaseQueued = false;
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
    return measureUseCaseEnabled ? "MGD measure mode" : "MGD";
  }
  if (menus == 1) {
    return measureUseCaseEnabled ? "MGI measure mode" : "MGI";
  }
  if (menus == 2) {
    return "CONTROL MANUELLE";
  }
  return "unknown";
}

float getActiveForceSafetyStopThresholdN() {
  if (measureUseCaseEnabled && isMeasureUseCaseSupportedTab()) {
    return max(0.0, measureUseCaseSafetyForceLimitN);
  }
  return max(0.0, forceSafetyStopThresholdN);
}

boolean shouldAutoReleaseMeasureSafetyStop() {
  return measureUseCaseEnabled &&
    isMeasureUseCaseSupportedTab() &&
    measureUseCaseAutoReleaseOnSafetyStop;
}

boolean queueMeasureSafetyAutoRelease(float rawForceN) {
  float deltaZMm = rawForceN >= 0 ? -measureUseCaseAutoReleaseDeltaMm : measureUseCaseAutoReleaseDeltaMm;
  if (measureUseCaseAutoReleaseInvertDirection) {
    deltaZMm = -deltaZMm;
  }

  float[] deltaToolPose = {0, 0, deltaZMm, 0, 0, 0};
  boolean commandQueued = sendRobotEmergencyToolDeltaCommand(deltaToolPose);
  if (commandQueued) {
    forceSafetyStopStatus =
      "measure safety stop latched at " + nf(forceSafetyStopTriggeredObservedForceN, 1, 2) +
      " N -> auto release queued (" + nf(deltaZMm, 1, 2) + " mm)";
  }
  return commandQueued;
}

boolean handleSafetyInterlockMousePressed(float px, float py) {
  if (!isForceSafetyStopLatched()) {
    return false;
  }

  if (shouldShowForceSafetyMeasureButton() &&
    isPointInRect(px, py, forceSafetyMeasureBtnX, forceSafetyMeasureBtnY, forceSafetyMeasureBtnW, forceSafetyMeasureBtnH)) {
    handleForceSafetySwitchToMeasure();
    return true;
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
  float line5Y = panelY + 176;
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
  text(
    forceSafetyStopAutoReleaseQueued
    ? "The force limit was exceeded in Measure mode. A small automatic release move is requested opposite to the measured force."
    : "The robot was stopped because the force threshold was exceeded outside manual control.",
    contentX,
    line1Y,
    panelW - 48,
    26
  );

  fill(220);
  textSize(13);
  text("Source tab: " + forceSafetyStopTriggerSource, contentX, line2Y);
  text("Measured force: " + nf(forceSafetyStopTriggeredForceN, 1, 2) + " N", contentX, line3Y);
  text("Observed threshold check: " + nf(forceSafetyStopTriggeredObservedForceN, 1, 2) + " N / limit " + nf(forceSafetyStopThresholdUsedN, 1, 2) + " N", contentX, line4Y);
  if (shouldShowForceSafetyMeasureButton()) {
    fill(255, 210, 120);
    text("Measure mode available here: safety limit would become " + nf(measureUseCaseSafetyForceLimitN, 1, 2) + " N.", contentX, line5Y);
  } else if (forceSafetyStopAutoReleaseQueued) {
    fill(255, 210, 120);
    text("Auto release delta: " + nf(getMeasureSafetyAutoReleaseDeltaMm(forceSafetyStopTriggeredForceN), 1, 2) + " mm on tool Z.", contentX, line5Y);
  }

  fill(200);
  textSize(12);
  text(
    shouldShowForceSafetyMeasureButton()
    ? "If you are intentionally pressing on the plate, switch to Measure mode first. The stop will auto-clear only if the current force is below the Measure limit."
    : "Reset is manual. If the force is still above threshold, the stop will trigger again.",
    contentX,
    panelY + panelH - 86,
    panelW - 48,
    32
  );

  forceSafetyResetBtnW = 186;
  forceSafetyResetBtnH = 32;
  forceSafetyResetBtnX = panelX + panelW - forceSafetyResetBtnW - 24;
  forceSafetyResetBtnY = buttonY;
  forceSafetyMeasureBtnW = 204;
  forceSafetyMeasureBtnH = 32;
  forceSafetyMeasureBtnX = contentX;
  forceSafetyMeasureBtnY = buttonY;

  // La popup propose soit un basculement vers le use case mesure, soit un reset manuel.
  if (shouldShowForceSafetyMeasureButton()) {
    drawSafetyInterlockButton(forceSafetyMeasureBtnX, forceSafetyMeasureBtnY, forceSafetyMeasureBtnW, forceSafetyMeasureBtnH, "Switch to Measure", true);
  }
  drawSafetyInterlockButton(forceSafetyResetBtnX, forceSafetyResetBtnY, forceSafetyResetBtnW, forceSafetyResetBtnH, "Reset safety stop", true);
  textAlign(LEFT, CENTER);
}

boolean shouldShowForceSafetyMeasureButton() {
  return !measureUseCaseEnabled && isMeasureUseCaseSupportedTab();
}

void handleForceSafetySwitchToMeasure() {
  enableMeasureUseCase();

  if (forceSensorPort == null || !isForceSensorFresh()) {
    forceSafetyStopStatus = "measure mode enabled from popup; waiting for fresh force data before reset";
    return;
  }

  float rawForceN = getForceSensorValueN();
  float observedForceN = forceSafetyStopUseAbsoluteValue ? abs(rawForceN) : rawForceN;
  float measureThresholdN = getActiveForceSafetyStopThresholdN();

  if (observedForceN <= measureThresholdN) {
    resetForceSafetyStopState("force safety stop cleared after switching to measure mode");
    bridgeCommandStatus = "measure mode enabled from safety popup";
    recordMoodleCsvEvent("force_safety_stop_reset");
    return;
  }

  forceSafetyStopStatus =
    "measure mode enabled, but force still above measure limit (" +
    nf(observedForceN, 1, 2) + " N > " + nf(measureThresholdN, 1, 2) + " N)";
}

float getMeasureSafetyAutoReleaseDeltaMm(float rawForceN) {
  float deltaZMm = rawForceN >= 0 ? -measureUseCaseAutoReleaseDeltaMm : measureUseCaseAutoReleaseDeltaMm;
  if (measureUseCaseAutoReleaseInvertDirection) {
    deltaZMm = -deltaZMm;
  }
  return deltaZMm;
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
