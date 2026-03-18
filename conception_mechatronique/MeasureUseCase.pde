// ============================================================================
// Use case "mesure" pour estimer la rigidite d'une plaque.
//
// Le mode s'appuie sur les briques existantes:
// - telemetrie robot live -> position Z courante
// - capteur de force -> effort courant
// - safety stop -> seuil dedie plus permissif qu'en usage standard
//
// Flux principal:
// 1. l'operateur active "Measure" depuis MGD ou MGI
// 2. le premier franchissement du seuil de depart est detecte
// 3. le Z de depart est interpole a cet instant
// 4. les couples Force/Z entre les deux seuils sont echantillonnes
// 5. le seuil d'arret est detecte, son Z est lui aussi interpole
// 6. une seule mesure synthetique est exportee dans le CSV dedie
// ============================================================================

boolean measureUseCaseEnabled = false;
boolean measureUseCaseContactDetected = false;
boolean measureUseCaseResultCaptured = false;
boolean measureUseCaseResultLogged = false;
boolean measureUseCaseHasPreviousSample = false;
String measureUseCaseStatus = "Measure mode OFF. Toggle Measure to arm a new plate test.";

float[] measureUseCaseContactCartesian = {0, 0, 0, 0, 0, 0};
float measureUseCaseContactForceN = 0.0;
float measureUseCaseResultForceN = 0.0;
float measureUseCaseResultPositionZMm = 0.0;
float measureUseCaseCurrentDeltaZMm = 0.0;
float measureUseCaseCurrentDeltaForceN = 0.0;
float measureUseCaseCurrentStiffnessNPerMm = 0.0;
boolean measureUseCaseStiffnessAvailable = false;
int measureUseCaseLastSampleMs = -1000;

float measureUseCasePreviousLiveForceN = 0.0;
float measureUseCasePreviousObservedForceN = 0.0;
float measureUseCasePreviousPositionZMm = 0.0;

java.util.ArrayList<Float> measureUseCaseSampleForcesN = new java.util.ArrayList<Float>();
java.util.ArrayList<Float> measureUseCaseSamplePositionsZMm = new java.util.ArrayList<Float>();

void setupMeasureUseCase() {
  disableMeasureUseCase("Measure mode OFF. Toggle Measure to arm a new plate test.");
}

void updateMeasureUseCase() {
  if (!measureUseCaseEnabled) {
    return;
  }

  if (!isMeasureUseCaseSupportedTab()) {
    disableMeasureUseCase("Measure mode disabled outside MGD/MGI.");
    return;
  }

  if (!hasLiveRobotPose) {
    measureUseCaseStatus = "Measure mode armed. Waiting for live robot pose.";
    return;
  }

  if (forceSensorPort == null) {
    measureUseCaseStatus = "Measure mode armed. Waiting for force sensor connection.";
    return;
  }

  if (forceSensorCalibrationPending || forceSensorAutoTarePending) {
    measureUseCaseStatus = "Measure mode armed. Waiting for force sensor tare.";
    return;
  }

  if (!isForceSensorFresh()) {
    measureUseCaseStatus = "Measure mode armed. Waiting for fresh force data.";
    return;
  }

  float liveForceN = getForceSensorValueN();
  float observedForceN = getMeasureUseCaseObservedForceN(liveForceN);
  float livePositionZMm = liveCartesian[2];

  if (!measureUseCaseHasPreviousSample) {
    rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm);
    if (observedForceN >= max(0.05, measureUseCaseContactForceThresholdN)) {
      measureUseCaseStatus = "Release below " + nf(measureUseCaseContactForceThresholdN, 1, 2) + " N, then press again to start the measurement window.";
    } else {
      measureUseCaseStatus = "Measure mode armed. Waiting for first contact at " + nf(measureUseCaseContactForceThresholdN, 1, 2) + " N.";
    }
    return;
  }

  if (!measureUseCaseContactDetected) {
    if (!didMeasureUseCaseThresholdCross(measureUseCasePreviousObservedForceN, observedForceN, measureUseCaseContactForceThresholdN)) {
      if (observedForceN >= max(0.05, measureUseCaseContactForceThresholdN)) {
        measureUseCaseStatus = "Force already above start threshold. Release below " + nf(measureUseCaseContactForceThresholdN, 1, 2) + " N to arm a clean measurement.";
      } else {
        measureUseCaseStatus = "Measure mode armed. Waiting for first contact at " + nf(measureUseCaseContactForceThresholdN, 1, 2) + " N.";
      }
      rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm);
      return;
    }

    captureMeasureUseCaseContactFromThresholdCrossing(liveForceN, observedForceN, livePositionZMm);

    if (didMeasureUseCaseThresholdCross(measureUseCasePreviousObservedForceN, observedForceN, measureUseCaseTargetForceThresholdN)) {
      captureMeasureUseCaseResultFromThresholdCrossing(liveForceN, observedForceN, livePositionZMm);
      rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm);
      return;
    }

    appendMeasureUseCaseCurrentWindowSampleIfNeeded(liveForceN, livePositionZMm);
    updateMeasureUseCaseDerivedValues(liveForceN, livePositionZMm);
    measureUseCaseStatus =
      "Measurement running between " + nf(measureUseCaseContactForceThresholdN, 1, 2) +
      " N and " + nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N.";
    rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm);
    return;
  }

  if (!measureUseCaseResultCaptured) {
    if (didMeasureUseCaseThresholdCross(measureUseCasePreviousObservedForceN, observedForceN, measureUseCaseTargetForceThresholdN)) {
      captureMeasureUseCaseResultFromThresholdCrossing(liveForceN, observedForceN, livePositionZMm);
    } else {
      appendMeasureUseCaseCurrentWindowSampleIfNeeded(liveForceN, livePositionZMm);
      updateMeasureUseCaseDerivedValues(liveForceN, livePositionZMm);
      measureUseCaseStatus =
        "Measurement running between " + nf(measureUseCaseContactForceThresholdN, 1, 2) +
        " N and " + nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N.";
    }
  } else {
    measureUseCaseStatus = "Measurement captured. Toggle Measure OFF/ON for a new plate test.";
  }

  rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm);
}

boolean isMeasureUseCaseSupportedTab() {
  return menus == 0 || menus == 1;
}

void toggleMeasureUseCase() {
  if (measureUseCaseEnabled) {
    disableMeasureUseCase("Measure mode OFF. Toggle Measure to arm a new plate test.");
  } else {
    enableMeasureUseCase();
  }
}

void enableMeasureUseCase() {
  measureUseCaseEnabled = true;
  measureUseCaseContactDetected = false;
  measureUseCaseResultCaptured = false;
  measureUseCaseResultLogged = false;
  measureUseCaseHasPreviousSample = false;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;
  measureUseCaseLastSampleMs = -1000;
  measureUseCasePreviousLiveForceN = 0.0;
  measureUseCasePreviousObservedForceN = 0.0;
  measureUseCasePreviousPositionZMm = 0.0;
  clearMeasureUseCaseSamples();
  zeroFloatArray(measureUseCaseContactCartesian);
  measureUseCaseContactForceN = 0.0;
  measureUseCaseResultForceN = 0.0;
  measureUseCaseResultPositionZMm = 0.0;
  measureUseCaseStatus = "Measure mode armed. Waiting for first contact on the plate.";

  if (measureUseCaseAutoReconnectSensor && forceSensorPort == null) {
    requestForceSensorReconnect();
  }
}

void disableMeasureUseCase(String nextStatus) {
  measureUseCaseEnabled = false;
  measureUseCaseContactDetected = false;
  measureUseCaseResultCaptured = false;
  measureUseCaseResultLogged = false;
  measureUseCaseHasPreviousSample = false;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;
  measureUseCaseLastSampleMs = -1000;
  measureUseCasePreviousLiveForceN = 0.0;
  measureUseCasePreviousObservedForceN = 0.0;
  measureUseCasePreviousPositionZMm = 0.0;
  clearMeasureUseCaseSamples();
  zeroFloatArray(measureUseCaseContactCartesian);
  measureUseCaseContactForceN = 0.0;
  measureUseCaseResultForceN = 0.0;
  measureUseCaseResultPositionZMm = 0.0;
  measureUseCaseStatus = nextStatus;
}

void clearMeasureUseCaseSamples() {
  measureUseCaseSampleForcesN.clear();
  measureUseCaseSamplePositionsZMm.clear();
}

float getMeasureUseCaseObservedForceN(float rawForceN) {
  return forceSafetyStopUseAbsoluteValue ? abs(rawForceN) : rawForceN;
}

boolean didMeasureUseCaseThresholdCross(float previousObservedForceN, float currentObservedForceN, float thresholdN) {
  return previousObservedForceN < thresholdN && currentObservedForceN >= thresholdN;
}

float computeMeasureUseCaseThresholdLerp(float previousObservedForceN, float currentObservedForceN, float thresholdN) {
  float deltaObservedForceN = currentObservedForceN - previousObservedForceN;
  if (abs(deltaObservedForceN) < 0.0001) {
    return 1.0;
  }

  return constrain((thresholdN - previousObservedForceN) / deltaObservedForceN, 0.0, 1.0);
}

float interpolateMeasureUseCaseForceN(float currentLiveForceN, float currentObservedForceN, float thresholdN) {
  float lerpT = computeMeasureUseCaseThresholdLerp(measureUseCasePreviousObservedForceN, currentObservedForceN, thresholdN);
  return lerp(measureUseCasePreviousLiveForceN, currentLiveForceN, lerpT);
}

float interpolateMeasureUseCasePositionZMm(float currentObservedForceN, float currentPositionZMm, float thresholdN) {
  float lerpT = computeMeasureUseCaseThresholdLerp(measureUseCasePreviousObservedForceN, currentObservedForceN, thresholdN);
  return lerp(measureUseCasePreviousPositionZMm, currentPositionZMm, lerpT);
}

void captureMeasureUseCaseContactFromThresholdCrossing(float currentLiveForceN, float currentObservedForceN, float currentPositionZMm) {
  float contactForceN = interpolateMeasureUseCaseForceN(currentLiveForceN, currentObservedForceN, measureUseCaseContactForceThresholdN);
  float contactPositionZMm = interpolateMeasureUseCasePositionZMm(currentObservedForceN, currentPositionZMm, measureUseCaseContactForceThresholdN);

  arrayCopy(liveCartesian, measureUseCaseContactCartesian);
  measureUseCaseContactCartesian[2] = contactPositionZMm;
  measureUseCaseContactForceN = contactForceN;
  measureUseCaseContactDetected = true;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;

  clearMeasureUseCaseSamples();
  appendMeasureUseCaseSampleNow(contactForceN, contactPositionZMm);
  measureUseCaseStatus =
    "Start threshold reached at " + nf(abs(contactForceN), 1, 2) +
    " N. Continue until " + nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N.";
}

void captureMeasureUseCaseResultFromThresholdCrossing(float currentLiveForceN, float currentObservedForceN, float currentPositionZMm) {
  float resultForceN = interpolateMeasureUseCaseForceN(currentLiveForceN, currentObservedForceN, measureUseCaseTargetForceThresholdN);
  float resultPositionZMm = interpolateMeasureUseCasePositionZMm(currentObservedForceN, currentPositionZMm, measureUseCaseTargetForceThresholdN);

  measureUseCaseResultCaptured = true;
  measureUseCaseResultForceN = resultForceN;
  measureUseCaseResultPositionZMm = resultPositionZMm;
  appendMeasureUseCaseSampleNow(resultForceN, resultPositionZMm);
  updateMeasureUseCaseDerivedValues(resultForceN, resultPositionZMm);
  measureUseCaseStatus = "Measurement captured at " + nf(abs(resultForceN), 1, 2) + " N.";
}

void appendMeasureUseCaseCurrentWindowSampleIfNeeded(float forceN, float positionZMm) {
  int now = millis();
  if (measureUseCaseLastSampleMs >= 0 && now - measureUseCaseLastSampleMs < max(10, measureUseCaseSampleIntervalMs)) {
    return;
  }

  appendMeasureUseCaseSampleNow(forceN, positionZMm);
}

void appendMeasureUseCaseSampleNow(float forceN, float positionZMm) {
  measureUseCaseSampleForcesN.add(forceN);
  measureUseCaseSamplePositionsZMm.add(positionZMm);
  measureUseCaseLastSampleMs = millis();
}

void updateMeasureUseCaseDerivedValues(float forceN, float positionZMm) {
  measureUseCaseCurrentDeltaZMm = positionZMm - measureUseCaseContactCartesian[2];
  measureUseCaseCurrentDeltaForceN = forceN - measureUseCaseContactForceN;
  measureUseCaseStiffnessAvailable = abs(measureUseCaseCurrentDeltaZMm) >= max(0.05, measureUseCaseMinDisplacementMm);

  float fittedStiffnessNPerMm = computeMeasureUseCaseWindowStiffnessNPerMm();
  if (!Float.isNaN(fittedStiffnessNPerMm) && fittedStiffnessNPerMm > 0.0) {
    measureUseCaseCurrentStiffnessNPerMm = fittedStiffnessNPerMm;
    measureUseCaseStiffnessAvailable = true;
  } else if (measureUseCaseStiffnessAvailable) {
    measureUseCaseCurrentStiffnessNPerMm = abs(measureUseCaseCurrentDeltaForceN) / abs(measureUseCaseCurrentDeltaZMm);
  } else {
    measureUseCaseCurrentStiffnessNPerMm = 0.0;
  }
}

float computeMeasureUseCaseWindowStiffnessNPerMm() {
  if (measureUseCaseSampleForcesN.size() < 2 || measureUseCaseSamplePositionsZMm.size() < 2) {
    return Float.NaN;
  }

  double sumXX = 0.0;
  double sumXY = 0.0;
  for (int i = 0; i < measureUseCaseSampleForcesN.size(); i++) {
    float deltaZMm = abs(measureUseCaseSamplePositionsZMm.get(i) - measureUseCaseContactCartesian[2]);
    float deltaForceN = abs(measureUseCaseSampleForcesN.get(i) - measureUseCaseContactForceN);
    if (deltaZMm < 0.0001) {
      continue;
    }

    sumXX += deltaZMm * deltaZMm;
    sumXY += deltaZMm * deltaForceN;
  }

  if (sumXX <= 0.0001) {
    return Float.NaN;
  }

  return (float)(sumXY / sumXX);
}

void rememberMeasureUseCasePreviousSample(float liveForceN, float observedForceN, float positionZMm) {
  measureUseCasePreviousLiveForceN = liveForceN;
  measureUseCasePreviousObservedForceN = observedForceN;
  measureUseCasePreviousPositionZMm = positionZMm;
  measureUseCaseHasPreviousSample = true;
}

float drawMeasureUseCasePanel(float x, float y, float w) {
  float h = 104;

  noStroke();
  fill(32, 36, 44, 220);
  rect(x, y, w, h, 12);

  color accent = measureUseCaseEnabled ? color(0, 255, 150) : color(160);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(12);
  text(measureUseCaseEnabled ? "MEASURE MODE - PLATE RIGIDITY" : "MEASURE MODE - OFF", x + 14, y + 10);

  fill(235);
  textSize(12);
  text(ellipsizeToWidth(measureUseCaseStatus, w - 28), x + 14, y + 28);

  fill(200);
  textSize(12);
  String contactLine = measureUseCaseContactDetected
    ? "Start " + nf(abs(measureUseCaseContactForceN), 1, 2) + " N | Z start " + nf(measureUseCaseContactCartesian[2], 1, 2) + " mm"
    : "Waiting start >= " + nf(measureUseCaseContactForceThresholdN, 1, 2) + " N | stop " + nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N";
  text(ellipsizeToWidth(contactLine, w - 28), x + 14, y + 48);

  String liveForceLabel = isForceSensorFresh() ? nf(getForceSensorValueN(), 1, 2) + " N" : "--.-- N";
  String liveZLabel = hasLiveRobotPose ? nf(liveCartesian[2], 1, 2) + " mm" : "--.-- mm";
  String rigidityLabel = measureUseCaseStiffnessAvailable
    ? nf(measureUseCaseCurrentStiffnessNPerMm, 1, 3) + " N/mm"
    : "--";
  String forceCapLabel = measureUseCaseResultCaptured
    ? nf(abs(measureUseCaseResultForceN), 1, 2) + " N"
    : nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N";
  String liveLine =
    "Live Force " + liveForceLabel +
    " | Live Z " + liveZLabel +
    " | dZ " + nf(measureUseCaseCurrentDeltaZMm, 1, 2) +
    " mm | Stop " + forceCapLabel +
    " | k~ " + rigidityLabel +
    " | safety " + nf(measureUseCaseSafetyForceLimitN, 1, 1) + " N";
  text(ellipsizeToWidth(liveLine, w - 28), x + 14, y + 66);

  fill(170);
  text(ellipsizeToWidth("CSV: " + getMeasureCsvFileLabel() + " | " + measureCsvStatus, w - 28), x + 14, y + 84);
  textAlign(LEFT, CENTER);

  return h;
}

void drawMeasureUseCaseToggleButton(float x, float y, float w, float h) {
  boolean isHover = isPointInRect(mouseX, mouseY, x, y, w, h);
  boolean isEnabled = isMeasureUseCaseSupportedTab();
  color fillColor = measureUseCaseEnabled ? color(0, 160, 110) : color(54, 60, 70);
  color strokeColor = measureUseCaseEnabled ? color(120, 220, 180) : color(110, 120, 140);

  if (!isEnabled) {
    fillColor = color(56, 56, 56);
    strokeColor = color(90);
  } else if (isHover) {
    fillColor = measureUseCaseEnabled ? color(0, 185, 128) : color(0, 120, 255);
    strokeColor = measureUseCaseEnabled ? color(160, 240, 205) : color(120, 190, 255);
    cursor(HAND);
  }

  stroke(strokeColor);
  strokeWeight(1.5);
  fill(fillColor);
  rect(x, y, w, h, 10);

  fill(isEnabled ? color(245) : color(150));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(measureUseCaseEnabled ? "Measure ON" : "Measure", x + w / 2, y + h / 2);
  textAlign(LEFT, CENTER);
}

String buildMeasureUseCaseFooterSegment() {
  if (!measureUseCaseEnabled) {
    return "";
  }

  if (!measureUseCaseContactDetected) {
    return "measure ON | waiting contact";
  }

  String rigidityLabel = measureUseCaseStiffnessAvailable
    ? nf(measureUseCaseCurrentStiffnessNPerMm, 1, 2) + " N/mm"
    : "pending";
  float footerForceCapN = measureUseCaseResultCaptured ? abs(measureUseCaseResultForceN) : measureUseCaseTargetForceThresholdN;
  return "measure ON | start " + nf(measureUseCaseContactForceThresholdN, 1, 2) +
    " N | stop " + nf(footerForceCapN, 1, 2) +
    " N | dZ " + nf(measureUseCaseCurrentDeltaZMm, 1, 2) +
    " mm | k~ " + rigidityLabel +
    (measureUseCaseResultCaptured ? " | captured" : " | arming");
}
