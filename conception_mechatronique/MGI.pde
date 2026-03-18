// ============================================================================
// Onglet MGI (Modele Geometrique Inverse).
// Cet ecran travaille en espace cartesien:
// - l'utilisateur edite X/Y/Z/Rx/Ry/Rz
// - une demande de validation IK est envoyee au bridge
// - le bridge repond plus tard via robot_pose.csv avec validation_* et joints
// - l'execution n'est autorisee que si la cible courante correspond exactement
//   a la derniere cible validee
//
// Chaine d'appel typique:
// clic "Validate"
// -> handleMgiActionButtonClick()
// -> commitAllMgiFields()
// -> sendRobotCartesianValidationCommand()
// -> RobotBridge.pde ecrit robot_command.csv
// -> RobotPoseBridge.exe calcule la validation
// -> loadRobotPoseFromBridge() recharge validation_status/validation_joints
// -> isCurrentMgiTargetValidated() autorise ensuite "Hold Send"
// ============================================================================

// Cible cartesienne courante et etat d'edition des champs MGI.
float[] cartesian = {300, 0, 200, 180, 0, 0};
String[] cartNames = {"X", "Y", "Z", "Rx", "Ry", "Rz"};
String[] cartUnits = {"mm", "mm", "mm", "deg", "deg", "deg"};
String[] mgiInputTexts = {"300.0", "0.0", "200.0", "180.0", "0.0", "0.0"};
int mgiActiveFieldIndex = -1;
boolean mgiReplaceSelectionOnNextInput = false;
boolean mgiInitialPoseCaptured = false;
boolean mgiSendHoldActive = false;
String mgiLocalStatus = "Edit a target or load the live pose, then validate.";

// Reinitialise l'etat local des champs MGI au demarrage du sketch.
void setupMgiUi() {
  syncMgiInputsFromTarget(cartesian);
  mgiInitialPoseCaptured = false;
  mgiLocalStatus = "Edit a target or load the live pose, then validate.";
}

// Onglet MGI: saisie de pose cartesienne, validation IK et execution.
void draw_menus_2() {
  float marginX = width * 0.05;
  float topY = getMgiTopY();
  float panelWidth = (width - (3 * marginX)) / 2;
  float rowSpacing = getMgiRowSpacing();
  float subtitleY = topY - 24;
  float controlsStartY = getMgiControlsStartY();

  fill(255);
  textSize(constrain(width / 40.0, 17, 27));
  text("MGI - cartesian target", marginX, topY - 45);
  textSize(constrain(width / 105.0, 10, 13));
  textAlign(LEFT, TOP);
  if (hasLiveRobotPose) {
    fill(0, 255, 100); 
    text("Fill the cartesian target, click Validate, then Send only after a valid IK solution is reported.", marginX, subtitleY, width - (2 * marginX), 36);
  }
  if (hasRobotConnection) {
    fill(0, 255, 100); 
    text("Robot connected, but motion is blocked until real mode and safety are confirmed by the bridge.", marginX, subtitleY, width - (2 * marginX), 36); 
  }
  fill(255, 80, 80);
  text("Reconnect the bridge or wait for a robot connection before validating or sending a target.", marginX, subtitleY, width - (2 * marginX), 36); 
  textAlign(LEFT, CENTER);

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;
    float x = marginX + (col * (panelWidth + marginX));
    float y = controlsStartY + (row * rowSpacing);
    // Chaque ligne affiche:
    // label + champ texte + steppers + unite + eventuelle valeur live.
    drawMgiFieldRow(i, x, y, panelWidth);
  }

  // Les boutons d'action reutilisent l'etat mis a jour par RobotBridge.pde
  // (validation, mode robot, statut de securite, etc.).
  drawMgiActionButtons();

  float buttonY = getMgiButtonsY();
  float buttonHeight = 38;
  float lowerPanelY = buttonY + buttonHeight + 18;
  float lowerPanelBottom = height - 48;
  float lowerPanelH = lowerPanelBottom - lowerPanelY;
  lowerPanelH = min(280, lowerPanelH);
  if (lowerPanelH < 110) {
    lowerPanelH = 110;
    lowerPanelY = lowerPanelBottom - lowerPanelH;
  }
  float lowerPanelW = width - (2 * marginX);
  float lowerGap = 14;
  boolean useStackedLayout = lowerPanelW < 880;

  if (useStackedLayout) {
    float solutionH = lowerPanelH * 0.50;
    float vizH = lowerPanelH - solutionH - lowerGap;
    if (vizH < 110) {
      vizH = 110;
      solutionH = lowerPanelH - vizH - lowerGap;
    }
    solutionH = max(95, solutionH);
    drawMgiSolutionPanel(marginX, lowerPanelY, lowerPanelW, solutionH);
    float vizW = constrain(lowerPanelW * 0.78, 320, 760);
    float vizX = marginX + (lowerPanelW - vizW) * 0.5;
    drawRobot3DPanel(vizX, lowerPanelY + solutionH + lowerGap, vizW, vizH, "3D robot preview (IK)");
  } else {
    float vizW = constrain(lowerPanelW * 0.34, 300, 430);
    float solutionW = lowerPanelW - vizW - lowerGap;
    if (solutionW < 320) {
      solutionW = 320;
      vizW = lowerPanelW - solutionW - lowerGap;
    }
    drawMgiSolutionPanel(marginX, lowerPanelY, solutionW, lowerPanelH);
    drawRobot3DPanel(marginX + solutionW + lowerGap, lowerPanelY, vizW, lowerPanelH, "3D robot preview (IK)");
  }
}

void drawMgiFieldRow(int index, float x, float y, float panelWidth) {
  float fieldX = x + (panelWidth * 0.28);
  float fieldWidth = panelWidth * 0.32;
  float fieldHeight = 34;
  float buttonSize = 26;
  float minusX = fieldX + fieldWidth + 12;
  float plusX = minusX + buttonSize + 8;
  float unitX = plusX + buttonSize + 12;
  boolean isFieldActive = (mgiActiveFieldIndex == index);

  fill(210);
  textSize(13);
  text(cartNames[index], x, y + 4);

  stroke(isFieldActive ? color(0, 120, 255) : color(85));
  strokeWeight(1.5);
  fill(28);
  rect(fieldX, y - 12, fieldWidth, fieldHeight, 8);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13);
  text(mgiInputTexts[index], fieldX + 10, y + 5);

  drawMgiStepperButton(minusX, y - 8, buttonSize, buttonSize, "-");
  drawMgiStepperButton(plusX, y - 8, buttonSize, buttonSize, "+");

  fill(150);
  textAlign(LEFT, CENTER);
  textSize(12);
  text(cartUnits[index], unitX, y + 4);

  if (hasLiveRobotPose) {
    fill(0, 255, 150);
    textAlign(LEFT, CENTER);
    textSize(11);
    text("live " + formatMgiValue(liveCartesian[index]), x, y + 30);
  }

  textAlign(LEFT, CENTER);
}

// Petit bouton + ou - place a droite d'un champ.
void drawMgiStepperButton(float x, float y, float w, float h, String label) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  stroke(isHover ? color(0, 120, 255) : color(90));
  strokeWeight(1.2);
  fill(isHover ? color(52, 58, 70) : color(40));
  rect(x, y, w, h, 7);

  fill(230);
  textAlign(CENTER, CENTER);
  textSize(16);
  text(label, x + w / 2, y + h / 2 - 1);
  textAlign(LEFT, CENTER);
}

// Rangee de boutons d'action MGI.
void drawMgiActionButtons() {
  float buttonY = getMgiButtonsY();
  float buttonHeight = 38;
  float gap = 16;
  float useLiveWidth = 150;
  float validateWidth = 128;
  float sendWidth = 128;
  float totalWidth = useLiveWidth + validateWidth + sendWidth + (2 * gap);
  float startX = (width - totalWidth) / 2.0;

  fill(150);
  textSize(12);
  text(buildCurrentMgiStatus(), startX, buttonY - 18);

  // Les boutons ne sont activables que si le bridge est capable de recevoir
  // une requete. L'execution demande en plus une validation encore "fraiche"
  // de la cible courante.
  drawMgiActionButton(startX, buttonY, useLiveWidth, buttonHeight, "Use live pose", hasLiveRobotPose, color(54, 60, 70));
  drawMgiActionButton(startX + useLiveWidth + gap, buttonY, validateWidth, buttonHeight, "Validate", canQueueBridgeRequest(), color(0, 120, 255));
  drawMgiActionButton(startX + useLiveWidth + gap + validateWidth + gap, buttonY, sendWidth, buttonHeight, mgiSendHoldActive ? "Holding..." : "Hold Send", canQueueBridgeRequest() && isCurrentMgiTargetValidated(), mgiSendHoldActive ? color(0, 180, 120) : color(0, 160, 110));
}

// Bouton d'action generique avec etat hover/disabled.
void drawMgiActionButton(float x, float y, float w, float h, String label, boolean enabled, color baseColor) {
  boolean isHover = enabled && isPointInRect(mouseX, mouseY, x, y, w, h);
  color fillColor = enabled ? baseColor : color(58);
  color strokeColor = enabled ? lerpColor(baseColor, color(255), 0.35) : color(90);

  if (isHover) {
    fillColor = lerpColor(baseColor, color(255), 0.18);
    cursor(HAND);
  }

  stroke(strokeColor);
  strokeWeight(1.5);
  fill(fillColor);
  rect(x, y, w, h, 10);

  fill(enabled ? color(245) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(label, x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}

// Panneau de retour sur la validation IK et la derniere solution calculee.
void drawMgiSolutionPanel(float x, float y, float w, float h) {
  // Ce panneau ne recalcule rien lui-meme: il met en forme le dernier etat
  // connu du bridge (validation, statut robot, statut securite, solution IK).
  noStroke();
  fill(32, 36, 44, 220);
  rect(x, y, w, h, 12);

  float titleY = y + 16;
  float line1Y = y + 36;
  float line2Y = y + 58;
  float line3Y = y + 76;
  float line4Y = y + 94;
  float line5Y = y + 112;
  float jointsY = y + h - 12;
  float maxLineW = max(80, w - 32);

  fill(255);
  textSize(constrain(width / 85.0, 11, 14));
  text("Inverse kinematics status", x + 16, titleY);

  boolean currentValidated = isCurrentMgiTargetValidated();
  fill(currentValidated ? color(0, 255, 150) : color(255, 180, 80));
  textSize(constrain(width / 105.0, 10, 12));
  text(ellipsizeToWidth(currentValidated ? "Current target validated and ready to send." : buildCurrentMgiStatus(), maxLineW), x + 16, line1Y);

  fill(200);
  if (line2Y < y + h - 12) text(ellipsizeToWidth("Validation: " + bridgeValidationStatus, maxLineW), x + 16, line2Y);
  if (line3Y < y + h - 12) text(ellipsizeToWidth("Mode: " + liveRobotModeStatus, maxLineW), x + 16, line3Y);
  if (line4Y < y + h - 12) text(ellipsizeToWidth("Safety: " + liveSafetyStatus, maxLineW), x + 16, line4Y);
  if (line5Y < y + h - 12) text(ellipsizeToWidth("CMD: " + bridgeCommandStatus, maxLineW), x + 16, line5Y);

  if (bridgeValidationPassed && jointsY > y + 120) {
    text(
      ellipsizeToWidth(
        "J1 " + formatMgiValue(bridgeValidationJoints[0]) +
        " | J2 " + formatMgiValue(bridgeValidationJoints[1]) +
        " | J3 " + formatMgiValue(bridgeValidationJoints[2]) +
        " | J4 " + formatMgiValue(bridgeValidationJoints[3]) +
        " | J5 " + formatMgiValue(bridgeValidationJoints[4]) +
        " | J6 " + formatMgiValue(bridgeValidationJoints[5]),
        maxLineW
      ),
      x + 16,
      jointsY
    );
  }
}

// Gere les clics dans l'onglet MGI: boutons, champ actif et steppers.
void handleMgiMousePressed(float px, float py) {
  if (handleMgiActionButtonClick(px, py)) {
    return;
  }

  int clickedField = findMgiFieldIndexAt(px, py);
  if (clickedField != -1) {
    mgiActiveFieldIndex = clickedField;
    mgiReplaceSelectionOnNextInput = true;
    return;
  }

  int stepButtonField = findMgiStepperFieldIndexAt(px, py);
  if (stepButtonField != -1) {
    boolean isPlus = isPointInRect(px, py, getMgiPlusX(stepButtonField), getMgiRowY(stepButtonField) - 8, 26, 26);
    nudgeMgiValue(stepButtonField, isPlus ? mgi_steps[stepButtonField] : -mgi_steps[stepButtonField]);
    return;
  }

  clearMgiActiveField();
}

// Route les clics sur "Use live pose", "Validate" et "Hold Send".
boolean handleMgiActionButtonClick(float px, float py) {
  float buttonY = getMgiButtonsY();
  float buttonHeight = 38;
  float gap = 16;
  float useLiveWidth = 150;
  float validateWidth = 128;
  float sendWidth = 128;
  float totalWidth = useLiveWidth + validateWidth + sendWidth + (2 * gap);
  float startX = (width - totalWidth) / 2.0;

  if (isPointInRect(px, py, startX, buttonY, useLiveWidth, buttonHeight)) {
    if (hasLiveRobotPose) {
      // On copie simplement la pose live dans les champs; aucune validation
      // n'est implicite, donc l'utilisateur doit ensuite recliquer Validate.
      syncMgiInputsFromTarget(liveCartesian);
      mgiLocalStatus = "Live pose loaded. Validate before sending.";
    } else {
      mgiLocalStatus = "Live pose unavailable. Wait for a real robot pose or reconnect.";
    }
    clearMgiActiveField();
    return true;
  }

  float validateX = startX + useLiveWidth + gap;
  if (isPointInRect(px, py, validateX, buttonY, validateWidth, buttonHeight)) {
    clearMgiActiveField();
    // Toute validation commence par figer les champs texte dans "cartesian".
    if (!commitAllMgiFields()) {
      return true;
    }
    if (!canQueueBridgeRequest()) {
      mgiLocalStatus = "Validation blocked: bridge unavailable.";
      return true;
    }
    // La reponse n'est pas immediate: le bridge ecrira plus tard le resultat
    // dans robot_pose.csv, qui sera reparce par loadRobotPoseFromBridge().
    sendRobotCartesianValidationCommand(cartesian);
    mgiLocalStatus = "Validation request queued.";
    return true;
  }

  float sendX = validateX + validateWidth + gap;
  if (isPointInRect(px, py, sendX, buttonY, sendWidth, buttonHeight)) {
    clearMgiActiveField();
    if (!commitAllMgiFields()) {
      return true;
    }
    if (!isCurrentMgiTargetValidated()) {
      mgiLocalStatus = "Validate the current target before sending.";
      return true;
    }
    // Le bouton est un "hold": on envoie l'execution au clic, puis un stop
    // au mouseReleased global pour laisser l'operateur garder la main.
    if (sendRobotCartesianExecuteCommand(cartesian)) {
      mgiSendHoldActive = true;
      mgiLocalStatus = "Hold Send to keep the robot moving. Release to stop.";
    }
    return true;
  }

  return false;
}

// Retrouve le champ de texte clique, s'il y en a un.
int findMgiFieldIndexAt(float px, float py) {
  for (int i = 0; i < 6; i++) {
    if (isPointInRect(px, py, getMgiFieldX(i), getMgiRowY(i) - 12, getMgiFieldWidth(), 34)) {
      return i;
    }
  }
  return -1;
}

// Retrouve la ligne dont un bouton + ou - a ete clique.
int findMgiStepperFieldIndexAt(float px, float py) {
  for (int i = 0; i < 6; i++) {
    if (isPointInRect(px, py, getMgiMinusX(i), getMgiRowY(i) - 8, 26, 26) ||
      isPointInRect(px, py, getMgiPlusX(i), getMgiRowY(i) - 8, 26, 26)) {
      return i;
    }
  }
  return -1;
}

// Edition clavier des champs cartesien.
void handleMgiKeyPressed() {
  if (mgiActiveFieldIndex < 0 || mgiActiveFieldIndex >= mgiInputTexts.length) {
    return;
  }

  if (key == TAB) {
    mgiActiveFieldIndex = (mgiActiveFieldIndex + 1) % mgiInputTexts.length;
    mgiReplaceSelectionOnNextInput = true;
    return;
  }

  if (keyCode == ENTER || keyCode == RETURN) {
    // Enter fige seulement le champ actif; il ne lance pas de validation bridge.
    commitMgiField(mgiActiveFieldIndex);
    return;
  }

  if (keyCode == BACKSPACE) {
    if (mgiReplaceSelectionOnNextInput) {
      mgiInputTexts[mgiActiveFieldIndex] = "";
      mgiReplaceSelectionOnNextInput = false;
      mgiLocalStatus = "Target changed. Validate again before sending.";
      return;
    }
    String current = mgiInputTexts[mgiActiveFieldIndex];
    if (current.length() > 0) {
      mgiInputTexts[mgiActiveFieldIndex] = current.substring(0, current.length() - 1);
      mgiLocalStatus = "Target changed. Validate again before sending.";
    }
    return;
  }

  if (keyCode == DELETE) {
    mgiInputTexts[mgiActiveFieldIndex] = "";
    mgiLocalStatus = "Target changed. Validate again before sending.";
    return;
  }

  if ((key >= '0' && key <= '9') || key == '-' || key == '.' || key == ',') {
    appendMgiCharacter(mgiActiveFieldIndex, key);
  }
}

// Le bouton "Hold Send" s'arrete au relachement de la souris.
void handleMgiMouseReleased() {
  if (mgiSendHoldActive) {
    mgiSendHoldActive = false;
    sendRobotStopCommand();
    mgiLocalStatus = "Send released. Stop requested.";
  }
}

// Ajoute un caractere dans un champ en appliquant les regles de saisie decimale.
void appendMgiCharacter(int index, char typed) {
  String current = mgiInputTexts[index];

  if (typed == ',') {
    typed = '.';
  }

  if (mgiReplaceSelectionOnNextInput) {
    mgiInputTexts[index] = "";
    current = "";
    mgiReplaceSelectionOnNextInput = false;
  }

  if (typed == '-') {
    if (current.length() == 0) {
      mgiInputTexts[index] = "-";
    }
    return;
  }

  if (typed == '.') {
    if (current.indexOf('.') == -1) {
      if (current.length() == 0 || current.equals("-")) {
        mgiInputTexts[index] += "0.";
      } else {
        mgiInputTexts[index] += ".";
      }
      mgiLocalStatus = "Target changed. Validate again before sending.";
    }
    return;
  }

  mgiInputTexts[index] += typed;
  mgiLocalStatus = "Target changed. Validate again before sending.";
}

// Valide toute la grille avant d'envoyer une commande au bridge.
boolean commitAllMgiFields() {
  // On commit chaque champ l'un apres l'autre pour pouvoir placer le focus
  // exactement sur celui qui pose probleme.
  for (int i = 0; i < mgiInputTexts.length; i++) {
    if (!commitMgiField(i)) {
      mgiActiveFieldIndex = i;
      return false;
    }
  }

  return true;
}

// Parse, borne et reformate un champ individuel.
boolean commitMgiField(int index) {
  if (index < 0 || index >= mgiInputTexts.length) {
    return true;
  }

  // La sequence est volontairement stricte:
  // 1. normaliser le texte ("1," -> "1.")
  // 2. parser en float
  // 3. borner dans les limites physiques
  // 4. reformater pour afficher une valeur canonique
  String normalizedValue = normalizeMgiInputText(mgiInputTexts[index]);
  if (normalizedValue.length() == 0) {
    mgiLocalStatus = "Invalid value for " + cartNames[index] + ".";
    return false;
  }

  float parsedValue = parseMgiInputValue(normalizedValue);
  if (Float.isNaN(parsedValue)) {
    mgiLocalStatus = "Invalid value for " + cartNames[index] + ".";
    return false;
  }

  float constrainedValue = constrain(parsedValue, cartesian_min[index], cartesian_max[index]);
  cartesian[index] = constrainedValue;
  mgiInputTexts[index] = formatMgiValue(constrainedValue);
  mgiReplaceSelectionOnNextInput = false;
  mgiLocalStatus = "Target changed. Validate again before sending.";
  return true;
}

// Incremente ou decremente un axe avec le pas configure.
void nudgeMgiValue(int index, float delta) {
  commitMgiField(index);
  float nextValue = constrain(cartesian[index] + delta, cartesian_min[index], cartesian_max[index]);
  cartesian[index] = nextValue;
  mgiInputTexts[index] = formatMgiValue(nextValue);
  mgiActiveFieldIndex = index;
  mgiReplaceSelectionOnNextInput = false;
  mgiLocalStatus = "Target changed. Validate again before sending.";
}

// Recopie une pose dans les champs affiches et dans la cible interne.
void syncMgiInputsFromTarget(float[] sourceValues) {
  for (int i = 0; i < cartesian.length; i++) {
    cartesian[i] = sourceValues[i];
    mgiInputTexts[i] = formatMgiValue(sourceValues[i]);
  }
  // Ce flag evite de recopier plusieurs fois la meme pose live initiale.
  mgiInitialPoseCaptured = true;
}

// Format d'affichage standard pour les valeurs MGI.
String formatMgiValue(float value) {
  return trim(nf(value, 1, 1));
}

// Etat utilisateur affiche au-dessus des boutons.
String buildCurrentMgiStatus() {
  // Priorite a l'etat de validation remonte par le bridge si celle-ci
  // concerne bien la cible actuellement affichee a l'ecran.
  boolean currentMatchesValidation = doTargetsMatch(cartesian, bridgeValidationTarget);
  if (currentMatchesValidation) {
    if (bridgeValidationPassed) {
      return "Current target validated. Ready to send.";
    }

    if (bridgeValidationStatus.length() > 0 && !bridgeValidationStatus.equals("not validated")) {
      return bridgeValidationStatus;
    }
  }

  if (mgiLocalStatus.length() > 0) {
    return mgiLocalStatus;
  }

  return "Edit a target or load the live pose, then validate.";
}

// Une cible est "validee" seulement si la validation correspond exactement a la cible courante.
boolean isCurrentMgiTargetValidated() {
  return bridgeValidationPassed && doTargetsMatch(cartesian, bridgeValidationTarget);
}

// Compare deux cibles avec une petite tolerance numerique.
boolean doTargetsMatch(float[] first, float[] second) {
  // Une petite tolerance evite qu'un simple bruit de formatage decimal
  // invalide une cible qui est en pratique identique.
  if (first == null || second == null || first.length < 6 || second.length < 6) {
    return false;
  }

  for (int i = 0; i < 6; i++) {
    if (abs(first[i] - second[i]) > 0.05) {
      return false;
    }
  }

  return true;
}

// Sortie propre du mode edition.
void clearMgiActiveField() {
  mgiActiveFieldIndex = -1;
  mgiReplaceSelectionOnNextInput = false;
}

// Invalide le cache de validation des qu'une condition change.
void clearMgiValidationCache(String statusMessage) {
  // Appelee notamment sur reconnect bridge ou quand un contexte global change.
  // On invalide tout ce qui depend d'une validation precedente.
  bridgeValidationPassed = false;
  bridgeValidationStatus = "not validated";
  zeroFloatArray(bridgeValidationTarget);
  zeroFloatArray(bridgeValidationJoints);
  mgiInitialPoseCaptured = false;
  mgiSendHoldActive = false;
  mgiLocalStatus = statusMessage;
}

// Helpers de layout pour garder une geometrie coherente quand la fenetre change.
float getMgiPanelWidth() {
  return (width - (3 * width * 0.05)) / 2.0;
}

float getMgiRowY(int index) {
  float topY = getMgiControlsStartY();
  float rowSpacing = getMgiRowSpacing();
  int row = index % 3;
  return topY + (row * rowSpacing);
}

float getMgiTopY() {
  return height * 0.15;
}

float getMgiControlsStartY() {
  return getMgiTopY() + 22;
}

float getMgiRowSpacing() {
  return height * 0.12;
}

float getMgiButtonsY() {
  return getMgiControlsStartY() + (3 * getMgiRowSpacing()) + 8;
}

float getMgiBaseX(int index) {
  float marginX = width * 0.05;
  float panelWidth = getMgiPanelWidth();
  int col = index / 3;
  return marginX + (col * (panelWidth + marginX));
}

float getMgiFieldX(int index) {
  return getMgiBaseX(index) + (getMgiPanelWidth() * 0.28);
}

float getMgiFieldWidth() {
  return getMgiPanelWidth() * 0.32;
}

float getMgiMinusX(int index) {
  return getMgiFieldX(index) + getMgiFieldWidth() + 12;
}

float getMgiPlusX(int index) {
  return getMgiMinusX(index) + 26 + 8;
}

// Au premier retour de telemetrie live, on peut precharger le formulaire avec la pose reelle.
void captureInitialMgiPoseFromRobotIfNeeded() {
  // Cette fonction est appelee depuis loadRobotPoseFromBridge() des qu'une vraie
  // pose live existe. Elle ne s'executera qu'une seule fois tant qu'on ne remet
  // pas explicitement mgiInitialPoseCaptured a false.
  if (!mgiInitialPoseCaptured && hasLiveRobotPose) {
    syncMgiInputsFromTarget(liveCartesian);
    mgiLocalStatus = "Initial live pose acquired. Validate before sending.";
  }
}

// Normalise les saisies intermediaires avant parse float.
String normalizeMgiInputText(String rawText) {
  String normalized = trim(rawText);
  normalized = normalized.replace(',', '.');
  if (normalized.equals("-") || normalized.equals(".") || normalized.equals("-.")) {
    return "";
  }

  if (normalized.startsWith(".")) {
    normalized = "0" + normalized;
  } else if (normalized.startsWith("-.")) {
    normalized = normalized.replace("-.", "-0.");
  }

  if (normalized.endsWith(".")) {
    normalized = normalized.substring(0, normalized.length() - 1);
  }

  return normalized;
}

// Parse tolerant avec retour NaN en cas d'echec.
float parseMgiInputValue(String rawText) {
  try {
    return Float.valueOf(rawText);
  } catch (Exception ex) {
    return Float.NaN;
  }
}
