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

final int MEASURE_PHASE_WAIT_CONTACT = 0;
final int MEASURE_PHASE_PAUSE_AFTER_CONTACT = 1;
final int MEASURE_PHASE_SLOW_APPROACH = 2;
final int MEASURE_PHASE_PAUSE_AFTER_RESULT = 3;
final int MEASURE_PHASE_LIFTING = 4;
final int MEASURE_PHASE_COMPLETE = 5;

boolean measureUseCaseEnabled = false;
boolean measureUseCaseContactDetected = false;
boolean measureUseCaseResultCaptured = false;
boolean measureUseCaseResultLogged = false;
boolean measureUseCaseHasPreviousSample = false;
boolean measureUseCasePreparationPending = false;
boolean measureUseCaseWindowHasZExtents = false;
boolean measureUseCaseLiftAfterCapturePending = false;
boolean measureUseCaseAutoExitPending = false;
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
int measureUseCaseLastProcessedForceSampleMs = -1;
int measureUseCasePhase = MEASURE_PHASE_WAIT_CONTACT;
int measureUseCasePhaseStartedMs = -1;
int measureUseCaseLastMotionCommandMs = -10000;

float measureUseCasePreviousLiveForceN = 0.0;
float measureUseCasePreviousObservedForceN = 0.0;
float measureUseCasePreviousPositionZMm = 0.0;
float measureUseCaseWindowMinZMm = 0.0;
float measureUseCaseWindowMaxZMm = 0.0;

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

  if (measureUseCasePreparationPending) {
    updateMeasureUseCasePreparation();
  }

  int now = millis();
  float liveForceN = getForceSensorValueN();
  float observedForceN = getMeasureUseCaseObservedForceN(liveForceN);
  float livePositionZMm = liveCartesian[2];
  int currentForceSampleMs = lastForceSensorResponseMs;

  if (shouldCompleteMeasureUseCaseAfterLift(now, observedForceN)) {
    completeMeasureUseCaseMode("Measure mode OFF. Last measurement captured and lift completed.");
    return;
  }

  updateMeasureUseCaseAutomation(now, observedForceN);

  if (currentForceSampleMs < 0) {
    measureUseCaseStatus = "Measure mode armed. Waiting for a usable force sample.";
    return;
  }

  if (currentForceSampleMs == measureUseCaseLastProcessedForceSampleMs) {
    return;
  }

  if (!measureUseCaseHasPreviousSample) {
    if (observedForceN >= max(0.05, measureUseCaseContactForceThresholdN)) {
      captureMeasureUseCaseContactFromCurrentSample(liveForceN, livePositionZMm, now);
      rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm, currentForceSampleMs);
      return;
    }

    rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm, currentForceSampleMs);
    measureUseCaseStatus = buildMeasureUseCaseAutoApproachStatus();
    return;
  }

  if (!measureUseCaseContactDetected) {
    if (!didMeasureUseCaseThresholdCross(measureUseCasePreviousObservedForceN, observedForceN, measureUseCaseContactForceThresholdN) &&
      observedForceN < max(0.05, measureUseCaseContactForceThresholdN)) {
      measureUseCaseStatus = buildMeasureUseCaseAutoApproachStatus();
      rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm, currentForceSampleMs);
      return;
    }

    if (didMeasureUseCaseThresholdCross(measureUseCasePreviousObservedForceN, observedForceN, measureUseCaseContactForceThresholdN)) {
      captureMeasureUseCaseContactFromThresholdCrossing(liveForceN, observedForceN, livePositionZMm, now);
    } else {
      captureMeasureUseCaseContactFromCurrentSample(liveForceN, livePositionZMm, now);
    }
    rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm, currentForceSampleMs);
    return;
  }

  if (!measureUseCaseResultCaptured) {
    if (measureUseCasePhase == MEASURE_PHASE_SLOW_APPROACH) {
      if (didMeasureUseCaseThresholdCross(measureUseCasePreviousObservedForceN, observedForceN, measureUseCaseTargetForceThresholdN) ||
        observedForceN >= measureUseCaseTargetForceThresholdN) {
        captureMeasureUseCaseResultFromThresholdCrossing(liveForceN, observedForceN, livePositionZMm, now);
      } else {
        appendMeasureUseCaseCurrentWindowSampleIfNeeded(liveForceN, livePositionZMm);
        updateMeasureUseCaseDerivedValues(liveForceN, livePositionZMm);
      }
    } else if (measureUseCasePhase == MEASURE_PHASE_PAUSE_AFTER_CONTACT) {
      measureUseCaseStatus = buildMeasureUseCaseContactPauseStatus();
    } else {
      appendMeasureUseCaseCurrentWindowSampleIfNeeded(liveForceN, livePositionZMm);
      updateMeasureUseCaseDerivedValues(liveForceN, livePositionZMm);
    }
  } else {
    if (measureUseCasePhase == MEASURE_PHASE_COMPLETE && !measureUseCaseLiftAfterCapturePending) {
      measureUseCaseStatus = "Measurement captured. Lift requested, waiting to leave Measure mode.";
    }
  }

  rememberMeasureUseCasePreviousSample(liveForceN, observedForceN, livePositionZMm, currentForceSampleMs);
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
  measureUseCasePreparationPending = measureUseCaseAutoPreparePoseEnabled;
  measureUseCaseLiftAfterCapturePending = false;
  measureUseCaseAutoExitPending = false;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;
  measureUseCaseLastSampleMs = -1000;
  measureUseCaseLastProcessedForceSampleMs = -1;
  measureUseCasePhase = MEASURE_PHASE_WAIT_CONTACT;
  measureUseCasePhaseStartedMs = -1;
  measureUseCaseLastMotionCommandMs = -10000;
  measureUseCasePreviousLiveForceN = 0.0;
  measureUseCasePreviousObservedForceN = 0.0;
  measureUseCasePreviousPositionZMm = 0.0;
  measureUseCaseWindowHasZExtents = false;
  measureUseCaseWindowMinZMm = 0.0;
  measureUseCaseWindowMaxZMm = 0.0;
  clearMeasureUseCaseSamples();
  zeroFloatArray(measureUseCaseContactCartesian);
  measureUseCaseContactForceN = 0.0;
  measureUseCaseResultForceN = 0.0;
  measureUseCaseResultPositionZMm = 0.0;
  measureUseCaseStatus = measureUseCasePreparationPending
    ? "Measure mode armed. Preparing tool-down pose from current point."
    : "Measure mode armed. Waiting for first contact on the plate.";

  if (measureUseCaseAutoReconnectSensor && forceSensorPort == null) {
    requestForceSensorReconnect();
  }
}

void disableMeasureUseCase(String nextStatus) {
  stopMeasureUseCaseMotionIfNeeded();
  measureUseCaseEnabled = false;
  measureUseCaseContactDetected = false;
  measureUseCaseResultCaptured = false;
  measureUseCaseResultLogged = false;
  measureUseCaseHasPreviousSample = false;
  measureUseCasePreparationPending = false;
  measureUseCaseLiftAfterCapturePending = false;
  measureUseCaseAutoExitPending = false;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;
  measureUseCaseLastSampleMs = -1000;
  measureUseCaseLastProcessedForceSampleMs = -1;
  measureUseCasePhase = MEASURE_PHASE_WAIT_CONTACT;
  measureUseCasePhaseStartedMs = -1;
  measureUseCaseLastMotionCommandMs = -10000;
  measureUseCasePreviousLiveForceN = 0.0;
  measureUseCasePreviousObservedForceN = 0.0;
  measureUseCasePreviousPositionZMm = 0.0;
  measureUseCaseWindowHasZExtents = false;
  measureUseCaseWindowMinZMm = 0.0;
  measureUseCaseWindowMaxZMm = 0.0;
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
  measureUseCaseWindowHasZExtents = false;
  measureUseCaseWindowMinZMm = 0.0;
  measureUseCaseWindowMaxZMm = 0.0;
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

void captureMeasureUseCaseContactFromThresholdCrossing(float currentLiveForceN, float currentObservedForceN, float currentPositionZMm, int nowMs) {
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
  measureUseCasePhase = MEASURE_PHASE_PAUSE_AFTER_CONTACT;
  measureUseCasePhaseStartedMs = nowMs;
  measureUseCaseLastMotionCommandMs = nowMs;
  measureUseCaseLiftAfterCapturePending = false;
  stopMeasureUseCaseMotionIfNeeded();
  measureUseCaseStatus = buildMeasureUseCaseContactPauseStatus();
}

void captureMeasureUseCaseContactFromCurrentSample(float currentLiveForceN, float currentPositionZMm, int nowMs) {
  arrayCopy(liveCartesian, measureUseCaseContactCartesian);
  measureUseCaseContactCartesian[2] = currentPositionZMm;
  measureUseCaseContactForceN = currentLiveForceN;
  measureUseCaseContactDetected = true;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;

  clearMeasureUseCaseSamples();
  appendMeasureUseCaseSampleNow(currentLiveForceN, currentPositionZMm);
  measureUseCasePhase = MEASURE_PHASE_PAUSE_AFTER_CONTACT;
  measureUseCasePhaseStartedMs = nowMs;
  measureUseCaseLastMotionCommandMs = nowMs;
  measureUseCaseLiftAfterCapturePending = false;
  stopMeasureUseCaseMotionIfNeeded();
  measureUseCaseStatus = buildMeasureUseCaseContactPauseStatus();
}

void captureMeasureUseCaseResultFromThresholdCrossing(float currentLiveForceN, float currentObservedForceN, float currentPositionZMm, int nowMs) {
  float resultForceN = interpolateMeasureUseCaseForceN(currentLiveForceN, currentObservedForceN, measureUseCaseTargetForceThresholdN);
  float interpolatedResultPositionZMm = interpolateMeasureUseCasePositionZMm(currentObservedForceN, currentPositionZMm, measureUseCaseTargetForceThresholdN);

  measureUseCaseResultCaptured = true;
  measureUseCaseResultForceN = resultForceN;
  appendMeasureUseCaseSampleNow(resultForceN, interpolatedResultPositionZMm);
  measureUseCaseResultPositionZMm = getMeasureUseCaseEffectiveResultPositionZMm(interpolatedResultPositionZMm);
  updateMeasureUseCaseDerivedValues(resultForceN, measureUseCaseResultPositionZMm);
  measureUseCasePhase = MEASURE_PHASE_PAUSE_AFTER_RESULT;
  measureUseCasePhaseStartedMs = nowMs;
  measureUseCaseLastMotionCommandMs = nowMs;
  measureUseCaseLiftAfterCapturePending = true;
  stopMeasureUseCaseMotionIfNeeded();
  if (measureUseCaseStiffnessAvailable) {
    measureUseCaseStatus = buildMeasureUseCaseResultPauseStatus();
  } else {
    measureUseCaseStatus = "Measurement captured, but no measurable Z variation was acquired before the stop threshold.";
  }
}

void updateMeasureUseCaseAutomation(int nowMs, float observedForceN) {
  if (!measureUseCaseContactDetected && measureUseCasePhase == MEASURE_PHASE_WAIT_CONTACT) {
    if (nowMs - measureUseCaseLastMotionCommandMs >= max(20, measureUseCaseApproachCommandIntervalMs)) {
      if (queueMeasureUseCaseAutoApproach(nowMs)) {
        measureUseCaseStatus = buildMeasureUseCaseAutoApproachStatus();
      } else {
        measureUseCaseStatus = "Measure auto approach paused: " + bridgeCommandStatus;
      }
    }
    return;
  }

  if (measureUseCaseResultCaptured && !measureUseCaseLiftAfterCapturePending && !measureUseCaseAutoExitPending) {
    return;
  }

  if (measureUseCasePhase == MEASURE_PHASE_PAUSE_AFTER_CONTACT) {
    if (nowMs - measureUseCasePhaseStartedMs < max(0, measureUseCasePauseAfterContactMs)) {
      measureUseCaseStatus = buildMeasureUseCaseContactPauseStatus();
      return;
    }

    if (queueMeasureUseCaseSlowApproach(nowMs)) {
      measureUseCasePhase = MEASURE_PHASE_SLOW_APPROACH;
      measureUseCasePhaseStartedMs = nowMs;
      measureUseCaseStatus = buildMeasureUseCaseSlowApproachStatus();
    } else {
      measureUseCaseStatus = "Contact recorded. Waiting to start the slow approach: " + bridgeCommandStatus;
    }
    return;
  }

  if (measureUseCasePhase == MEASURE_PHASE_SLOW_APPROACH) {
    if (nowMs - measureUseCaseLastMotionCommandMs >= max(20, measureUseCaseSlowApproachCommandIntervalMs)) {
      if (queueMeasureUseCaseSlowApproach(nowMs)) {
        measureUseCaseStatus = buildMeasureUseCaseSlowApproachStatus();
      } else {
        measureUseCaseStatus = "Slow approach paused: " + bridgeCommandStatus;
      }
    }
    return;
  }

  if (measureUseCasePhase == MEASURE_PHASE_PAUSE_AFTER_RESULT && measureUseCaseLiftAfterCapturePending) {
    if (nowMs - measureUseCasePhaseStartedMs < max(0, measureUseCasePauseAfterResultMs)) {
      measureUseCaseStatus = buildMeasureUseCaseResultPauseStatus();
      return;
    }

    if (queueMeasureUseCaseLiftAfterCapture(nowMs)) {
      measureUseCaseLiftAfterCapturePending = false;
      measureUseCaseAutoExitPending = true;
      measureUseCasePhase = MEASURE_PHASE_LIFTING;
      measureUseCasePhaseStartedMs = nowMs;
      measureUseCaseStatus =
        "Measurement captured. Lift in Z requested. Measure stays active until force drops below " +
        nf(measureUseCaseLiftExitForceThresholdN, 1, 2) + " N.";
    } else {
      measureUseCaseStatus = "Measurement captured. Waiting to lift: " + bridgeCommandStatus;
    }
    return;
  }

  if (measureUseCasePhase == MEASURE_PHASE_LIFTING) {
    measureUseCaseStatus =
      "Measurement captured. Robot lifting in Z. Measure stays active until force drops below " +
      nf(measureUseCaseLiftExitForceThresholdN, 1, 2) + " N.";
  }
}

boolean queueMeasureUseCaseAutoApproach(int nowMs) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "measure auto approach blocked: " + getMotionBlockReason();
    return false;
  }

  float[] toolVelocity = {0, 0, getMeasureUseCaseApproachVelocityMmS(), 0, 0, 0};
  boolean commandQueued = sendRobotToolVelocityCommand(toolVelocity);
  if (commandQueued) {
    measureUseCaseLastMotionCommandMs = nowMs;
  }
  return commandQueued;
}

boolean queueMeasureUseCaseSlowApproach(int nowMs) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "measure slow approach blocked: " + getMotionBlockReason();
    return false;
  }

  float[] toolVelocity = {0, 0, getMeasureUseCaseSlowApproachVelocityMmS(), 0, 0, 0};
  boolean commandQueued = sendRobotToolVelocityCommand(toolVelocity);
  if (commandQueued) {
    measureUseCaseLastMotionCommandMs = nowMs;
  }
  return commandQueued;
}

boolean queueMeasureUseCaseLiftAfterCapture(int nowMs) {
  if (!canQueueMotionCommand()) {
    bridgeCommandStatus = "measure lift blocked: " + getMotionBlockReason();
    return false;
  }

  float[] deltaToolPose = {0, 0, getMeasureUseCaseLiftDeltaMm(), 0, 0, 0};
  boolean commandQueued = sendRobotToolDeltaCommand(deltaToolPose);
  if (commandQueued) {
    measureUseCaseLastMotionCommandMs = nowMs;
  }
  return commandQueued;
}

boolean shouldCompleteMeasureUseCaseAfterLift(int nowMs, float observedForceN) {
  if (!measureUseCaseAutoExitPending || !measureUseCaseResultLogged || measureUseCasePhase != MEASURE_PHASE_LIFTING) {
    return false;
  }

  if (nowMs - measureUseCasePhaseStartedMs < max(0, measureUseCaseLiftExitDelayMs)) {
    return false;
  }

  return observedForceN <= max(0.05, measureUseCaseLiftExitForceThresholdN);
}

void stopMeasureUseCaseMotionIfNeeded() {
  homeButtonHoldActive = false;
  mgiSendHoldActive = false;
  if (canQueueBridgeRequest()) {
    sendRobotStopCommand();
  }
}

float getMeasureUseCaseApproachVelocityMmS() {
  float approachVelocityMmS = abs(measureUseCaseApproachVelocityMmS);
  if (measureUseCaseSlowApproachInvertDirection) {
    approachVelocityMmS = -approachVelocityMmS;
  }
  return approachVelocityMmS;
}

float getMeasureUseCaseSlowApproachVelocityMmS() {
  float approachVelocityMmS = abs(measureUseCaseSlowApproachVelocityMmS);
  if (measureUseCaseSlowApproachInvertDirection) {
    approachVelocityMmS = -approachVelocityMmS;
  }
  return approachVelocityMmS;
}

float getMeasureUseCaseLiftDeltaMm() {
  float liftDeltaMm = abs(measureUseCaseLiftAfterCaptureDeltaMm);
  return getMeasureUseCaseSlowApproachVelocityMmS() >= 0.0 ? -liftDeltaMm : liftDeltaMm;
}

String buildMeasureUseCaseAutoApproachStatus() {
  return "Measure ON. Auto approach descending on Z at " +
    nf(abs(getMeasureUseCaseApproachVelocityMmS()), 1, 2) +
    " mm/s until contact at " + nf(measureUseCaseContactForceThresholdN, 1, 2) + " N.";
}

String buildMeasureUseCaseContactPauseStatus() {
  return "Contact detected at " + nf(abs(measureUseCaseContactForceN), 1, 2) +
    " N. Robot fully stopped for " + nf(max(0, measureUseCasePauseAfterContactMs) / 1000.0, 1, 1) +
    " s, recording Z start, then slow approach toward " +
    nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N.";
}

String buildMeasureUseCaseSlowApproachStatus() {
  return "Contact recorded. Slow approach running at " +
    nf(abs(getMeasureUseCaseSlowApproachVelocityMmS()), 1, 2) +
    " mm/s toward " + nf(measureUseCaseTargetForceThresholdN, 1, 2) + " N.";
}

String buildMeasureUseCaseResultPauseStatus() {
  return "Target force reached at " + nf(abs(measureUseCaseResultForceN), 1, 2) +
    " N. Robot stopped, recording Z stop, then lifting in Z.";
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
  updateMeasureUseCaseZExtents(positionZMm);
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

void updateMeasureUseCaseZExtents(float positionZMm) {
  if (!measureUseCaseWindowHasZExtents) {
    measureUseCaseWindowHasZExtents = true;
    measureUseCaseWindowMinZMm = positionZMm;
    measureUseCaseWindowMaxZMm = positionZMm;
    return;
  }

  measureUseCaseWindowMinZMm = min(measureUseCaseWindowMinZMm, positionZMm);
  measureUseCaseWindowMaxZMm = max(measureUseCaseWindowMaxZMm, positionZMm);
}

float getMeasureUseCaseEffectiveResultPositionZMm(float fallbackPositionZMm) {
  float effectivePositionZMm = fallbackPositionZMm;
  float contactPositionZMm = measureUseCaseContactCartesian[2];

  if (!measureUseCaseWindowHasZExtents) {
    return effectivePositionZMm;
  }

  float currentDeltaZMm = abs(effectivePositionZMm - contactPositionZMm);
  float minDeltaZMm = abs(measureUseCaseWindowMinZMm - contactPositionZMm);
  float maxDeltaZMm = abs(measureUseCaseWindowMaxZMm - contactPositionZMm);

  if (minDeltaZMm > currentDeltaZMm && minDeltaZMm >= maxDeltaZMm) {
    effectivePositionZMm = measureUseCaseWindowMinZMm;
    currentDeltaZMm = minDeltaZMm;
  }

  if (maxDeltaZMm > currentDeltaZMm) {
    effectivePositionZMm = measureUseCaseWindowMaxZMm;
  }

  return effectivePositionZMm;
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

boolean hasMeasureUseCaseExportableResult() {
  return measureUseCaseResultCaptured &&
    measureUseCaseStiffnessAvailable &&
    abs(measureUseCaseCurrentDeltaZMm) >= max(0.05, measureUseCaseMinDisplacementMm);
}

void completeMeasureUseCaseMode(String nextStatus) {
  measureUseCaseEnabled = false;
  measureUseCaseContactDetected = false;
  measureUseCaseResultCaptured = false;
  measureUseCaseResultLogged = false;
  measureUseCaseHasPreviousSample = false;
  measureUseCasePreparationPending = false;
  measureUseCaseWindowHasZExtents = false;
  measureUseCaseLiftAfterCapturePending = false;
  measureUseCaseAutoExitPending = false;
  measureUseCaseCurrentDeltaZMm = 0.0;
  measureUseCaseCurrentDeltaForceN = 0.0;
  measureUseCaseCurrentStiffnessNPerMm = 0.0;
  measureUseCaseStiffnessAvailable = false;
  measureUseCaseLastSampleMs = -1000;
  measureUseCaseLastProcessedForceSampleMs = -1;
  measureUseCasePhase = MEASURE_PHASE_COMPLETE;
  measureUseCasePhaseStartedMs = -1;
  measureUseCaseLastMotionCommandMs = -10000;
  measureUseCasePreviousLiveForceN = 0.0;
  measureUseCasePreviousObservedForceN = 0.0;
  measureUseCasePreviousPositionZMm = 0.0;
  measureUseCaseWindowMinZMm = 0.0;
  measureUseCaseWindowMaxZMm = 0.0;
  clearMeasureUseCaseSamples();
  zeroFloatArray(measureUseCaseContactCartesian);
  measureUseCaseContactForceN = 0.0;
  measureUseCaseResultForceN = 0.0;
  measureUseCaseResultPositionZMm = 0.0;
  measureUseCaseStatus = nextStatus;
}

void rememberMeasureUseCasePreviousSample(float liveForceN, float observedForceN, float positionZMm, int forceSampleMs) {
  measureUseCasePreviousLiveForceN = liveForceN;
  measureUseCasePreviousObservedForceN = observedForceN;
  measureUseCasePreviousPositionZMm = positionZMm;
  measureUseCaseLastProcessedForceSampleMs = forceSampleMs;
  measureUseCaseHasPreviousSample = true;
}

void updateMeasureUseCasePreparation() {
  if (!measureUseCasePreparationPending) {
    return;
  }

  if (!hasLiveRobotPose || !canQueueMotionCommand()) {
    return;
  }

  float[] targetCartesian = buildMeasureUseCasePreparationTarget();
  boolean commandQueued = sendRobotCartesianAutoExecuteCommand(targetCartesian);
  if (commandQueued) {
    measureUseCaseStatus = "Measure mode armed. Tool-down pose requested. Wait for first contact.";
  } else {
    measureUseCaseStatus = "Measure mode armed. Tool-down preparation failed: " + bridgeCommandStatus;
  }
  measureUseCasePreparationPending = false;
}

float[] buildMeasureUseCasePreparationTarget() {
  float[] targetCartesian = {
    liveCartesian[0],
    liveCartesian[1],
    liveCartesian[2],
    measureUseCasePrepareRollDeg,
    measureUseCasePreparePitchDeg,
    measureUseCasePrepareKeepCurrentYaw ? liveCartesian[5] : measureUseCasePrepareYawDeg
  };
  return targetCartesian;
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
    return "measure ON | auto approach";
  }

  String phaseLabel = "contact recorded";
  if (measureUseCasePhase == MEASURE_PHASE_PAUSE_AFTER_CONTACT) {
    phaseLabel = "contact stop";
  } else if (measureUseCasePhase == MEASURE_PHASE_SLOW_APPROACH) {
    phaseLabel = "slow approach";
  } else if (measureUseCasePhase == MEASURE_PHASE_PAUSE_AFTER_RESULT) {
    phaseLabel = "target stop";
  } else if (measureUseCasePhase == MEASURE_PHASE_LIFTING) {
    phaseLabel = "lifting";
  } else if (measureUseCasePhase == MEASURE_PHASE_COMPLETE) {
    phaseLabel = "complete";
  }

  String rigidityLabel = measureUseCaseStiffnessAvailable
    ? nf(measureUseCaseCurrentStiffnessNPerMm, 1, 2) + " N/mm"
    : "pending";
  float footerForceCapN = measureUseCaseResultCaptured ? abs(measureUseCaseResultForceN) : measureUseCaseTargetForceThresholdN;
  return "measure ON | " + phaseLabel +
    " | start " + nf(measureUseCaseContactForceThresholdN, 1, 2) +
    " N | stop " + nf(footerForceCapN, 1, 2) +
    " N | dZ " + nf(measureUseCaseCurrentDeltaZMm, 1, 2) +
    " mm | k~ " + rigidityLabel +
    (measureUseCaseResultCaptured ? " | captured" : " | arming");
}
