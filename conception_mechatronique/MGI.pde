float[] cartesian = {300, 0, 200, 180, 0, 0};
String[] cartNames = {"X", "Y", "Z", "Rx", "Ry", "Rz"};
String[] cartUnits = {"mm", "mm", "mm", "deg", "deg", "deg"};
String[] mgiInputTexts = {"300.0", "0.0", "200.0", "180.0", "0.0", "0.0"};
int mgiActiveFieldIndex = -1;
boolean mgiReplaceSelectionOnNextInput = false;
boolean mgiInitialPoseCaptured = false;
boolean mgiSendHoldActive = false;
String mgiLocalStatus = "Edit a target or load the live pose, then validate.";

void setupMgiUi() {
  syncMgiInputsFromTarget(cartesian);
  mgiInitialPoseCaptured = false;
  mgiLocalStatus = "Edit a target or load the live pose, then validate.";
}

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

  fill(150);
  textSize(constrain(width / 105.0, 10, 13));
  textAlign(LEFT, TOP);
  text(buildMgiInstructionText(), marginX, subtitleY, width - (2 * marginX), 36);
  textAlign(LEFT, CENTER);

  for (int i = 0; i < 6; i++) {
    int col = i / 3;
    int row = i % 3;
    float x = marginX + (col * (panelWidth + marginX));
    float y = controlsStartY + (row * rowSpacing);
    drawMgiFieldRow(i, x, y, panelWidth);
  }

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

String buildMgiInstructionText() {
  if (hasLiveRobotPose) {
    return "Fill the cartesian target, click Validate, then Send only after a valid IK solution is reported.";
  }

  if (hasRobotConnection) {
    return "Robot connected, but motion is blocked until real mode and safety are confirmed by the bridge.";
  }

  return "Reconnect the bridge or wait for a robot connection before validating or sending a target.";
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

  drawMgiActionButton(startX, buttonY, useLiveWidth, buttonHeight, "Use live pose", hasLiveRobotPose, color(54, 60, 70));
  drawMgiActionButton(startX + useLiveWidth + gap, buttonY, validateWidth, buttonHeight, "Validate", canQueueBridgeRequest(), color(0, 120, 255));
  drawMgiActionButton(startX + useLiveWidth + gap + validateWidth + gap, buttonY, sendWidth, buttonHeight, mgiSendHoldActive ? "Holding..." : "Hold Send", canQueueBridgeRequest() && isCurrentMgiTargetValidated(), mgiSendHoldActive ? color(0, 180, 120) : color(0, 160, 110));
}

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

void drawMgiSolutionPanel(float x, float y, float w, float h) {
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
      syncMgiInputsFromTarget(liveCartesian);
      fill(0, 255, 100); 
      mgiLocalStatus = "Live pose loaded. Validate before sending.";
    } else {
      fill(255, 80, 80);
      mgiLocalStatus = "Live pose unavailable. Wait for a real robot pose or reconnect.";
    }
    clearMgiActiveField();
    return true;
  }

  float validateX = startX + useLiveWidth + gap;
  if (isPointInRect(px, py, validateX, buttonY, validateWidth, buttonHeight)) {
    clearMgiActiveField();
    if (!commitAllMgiFields()) {
      return true;
    }
    if (!canQueueBridgeRequest()) {
      mgiLocalStatus = "Validation blocked: bridge unavailable.";
      return true;
    }
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
    if (sendRobotCartesianExecuteCommand(cartesian)) {
      mgiSendHoldActive = true;
      mgiLocalStatus = "Hold Send to keep the robot moving. Release to stop.";
    }
    return true;
  }

  return false;
}

int findMgiFieldIndexAt(float px, float py) {
  for (int i = 0; i < 6; i++) {
    if (isPointInRect(px, py, getMgiFieldX(i), getMgiRowY(i) - 12, getMgiFieldWidth(), 34)) {
      return i;
    }
  }
  return -1;
}

int findMgiStepperFieldIndexAt(float px, float py) {
  for (int i = 0; i < 6; i++) {
    if (isPointInRect(px, py, getMgiMinusX(i), getMgiRowY(i) - 8, 26, 26) ||
      isPointInRect(px, py, getMgiPlusX(i), getMgiRowY(i) - 8, 26, 26)) {
      return i;
    }
  }
  return -1;
}

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

void handleMgiMouseReleased() {
  if (mgiSendHoldActive) {
    mgiSendHoldActive = false;
    sendRobotStopCommand();
    mgiLocalStatus = "Send released. Stop requested.";
  }
}

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

boolean commitAllMgiFields() {
  for (int i = 0; i < mgiInputTexts.length; i++) {
    if (!commitMgiField(i)) {
      mgiActiveFieldIndex = i;
      return false;
    }
  }

  return true;
}

boolean commitMgiField(int index) {
  if (index < 0 || index >= mgiInputTexts.length) {
    return true;
  }

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

void nudgeMgiValue(int index, float delta) {
  commitMgiField(index);
  float nextValue = constrain(cartesian[index] + delta, cartesian_min[index], cartesian_max[index]);
  cartesian[index] = nextValue;
  mgiInputTexts[index] = formatMgiValue(nextValue);
  mgiActiveFieldIndex = index;
  mgiReplaceSelectionOnNextInput = false;
  mgiLocalStatus = "Target changed. Validate again before sending.";
}

void syncMgiInputsFromTarget(float[] sourceValues) {
  for (int i = 0; i < cartesian.length; i++) {
    cartesian[i] = sourceValues[i];
    mgiInputTexts[i] = formatMgiValue(sourceValues[i]);
  }
  mgiInitialPoseCaptured = true;
}

String formatMgiValue(float value) {
  return trim(nf(value, 1, 1));
}

String buildCurrentMgiStatus() {
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

boolean isCurrentMgiTargetValidated() {
  return bridgeValidationPassed && doTargetsMatch(cartesian, bridgeValidationTarget);
}

boolean doTargetsMatch(float[] first, float[] second) {
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

void clearMgiActiveField() {
  mgiActiveFieldIndex = -1;
  mgiReplaceSelectionOnNextInput = false;
}

void clearMgiValidationCache(String statusMessage) {
  bridgeValidationPassed = false;
  bridgeValidationStatus = "not validated";
  zeroFloatArray(bridgeValidationTarget);
  zeroFloatArray(bridgeValidationJoints);
  mgiInitialPoseCaptured = false;
  mgiSendHoldActive = false;
  mgiLocalStatus = statusMessage;
}

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

void captureInitialMgiPoseFromRobotIfNeeded() {
  if (!mgiInitialPoseCaptured && hasLiveRobotPose) {
    syncMgiInputsFromTarget(liveCartesian);
    mgiLocalStatus = "Initial live pose acquired. Validate before sending.";
  }
}

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

float parseMgiInputValue(String rawText) {
  try {
    return Float.valueOf(rawText);
  } catch (Exception ex) {
    return Float.NaN;
  }
}
