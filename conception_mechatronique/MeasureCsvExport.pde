// ============================================================================
// Export CSV dedie au use case "Measure".
//
// Contrairement au CSV Moodle, ce fichier n'est renseigne que pour le use case
// de rigidite. Il vise une lecture simple apres essai:
// - une session de mesure = un identifiant simple
// - une seule ligne est ecrite quand le cap de force est atteint
// ============================================================================

String measureCsvPath = "";
String measureCsvStatus = "Measure CSV ready";
int measureCsvRowsWritten = 0;
int measureCsvSessionId = 0;
boolean measureCsvLastModeEnabled = false;
boolean measureCsvLastResultCaptured = false;

void setupMeasureCsvExport() {
  measureCsvPath = sketchPath(measureCsvFileName);
  measureCsvStatus = "Measure CSV ready -> " + getMeasureCsvFileLabel();
  measureCsvRowsWritten = 0;
  measureCsvSessionId = 0;
  measureCsvLastModeEnabled = false;
  measureCsvLastResultCaptured = false;
  ensureMeasureCsvHeader();
}

void updateMeasureCsvExport() {
  boolean modeJustEnabled = measureUseCaseEnabled && !measureCsvLastModeEnabled;
  boolean modeJustDisabled = !measureUseCaseEnabled && measureCsvLastModeEnabled;
  boolean resultJustCaptured = measureUseCaseResultCaptured && !measureCsvLastResultCaptured;

  if (modeJustEnabled) {
    measureCsvSessionId++;
    measureCsvStatus = "measure session " + measureCsvSessionId + " armed";
  } else if (modeJustDisabled) {
    measureCsvStatus = "measure session stopped";
  }

  if (measureUseCaseEnabled &&
    measureUseCaseResultCaptured &&
    !measureUseCaseResultLogged &&
    resultJustCaptured &&
    appendMeasureCsvSummaryRow()) {
    measureUseCaseResultLogged = true;
  }

  measureCsvLastModeEnabled = measureUseCaseEnabled;
  measureCsvLastResultCaptured = measureUseCaseResultCaptured;
}

boolean ensureMeasureCsvHeader() {
  if (measureCsvPath.length() == 0) {
    return false;
  }

  String headerLine = buildMeasureCsvHeaderLine();
  File csvFile = new File(measureCsvPath);
  if (csvFile.exists() && csvFile.length() > 0 && measureCsvAppendToExistingFile) {
    String[] existingLines = readBridgeTextFile(measureCsvPath);
    if (existingLines != null && existingLines.length > 0 && trim(existingLines[0]).equals(headerLine)) {
      return true;
    }
  }

  boolean writeOk = writeBridgeTextFileNow(measureCsvPath, new String[] { headerLine });
  if (writeOk) {
    measureCsvStatus = "measure csv header ready";
  }
  return writeOk;
}

boolean appendMeasureCsvSummaryRow() {
  if (measureCsvPath.length() == 0) {
    return false;
  }

  if (!ensureMeasureCsvHeader()) {
    measureCsvStatus = "measure csv header unavailable";
    return false;
  }

  try {
    File csvFile = new File(measureCsvPath);
    File parentDir = csvFile.getParentFile();
    if (parentDir != null && !parentDir.exists()) {
      parentDir.mkdirs();
    }

    java.util.List<String> line = java.util.Collections.singletonList(buildMeasureCsvSummaryLine());
    java.nio.file.Files.write(
      csvFile.toPath(),
      line,
      java.nio.charset.StandardCharsets.UTF_8,
      java.nio.file.StandardOpenOption.CREATE,
      java.nio.file.StandardOpenOption.APPEND
    );

    measureCsvRowsWritten++;
    measureCsvStatus = "measure result saved -> session " + measureCsvSessionId;
    return true;
  } catch (Exception ex) {
    measureCsvStatus = "measure csv append failed";
    return false;
  }
}

String buildMeasureCsvHeaderLine() {
  String[] columns = {
    "Timestamp",
    "MeasureSessionId",
    "ForceStartN",
    "ForceStopN",
    "PositionZStartMm",
    "PositionZStopMm",
    "DeltaZMm",
    "StiffnessNPerMm"
  };
  return join(columns, ";");
}

String buildMeasureCsvSummaryLine() {
  float stiffnessValue = measureUseCaseStiffnessAvailable ? measureUseCaseCurrentStiffnessNPerMm : Float.NaN;

  String[] values = {
    measureCsvEscape(buildMoodleCsvTimestamp()),
    str(max(1, measureCsvSessionId)),
    csvFloatOrBlank(abs(measureUseCaseContactForceN)),
    csvFloatOrBlank(abs(measureUseCaseResultForceN)),
    csvFloatOrBlank(measureUseCaseContactCartesian[2]),
    csvFloatOrBlank(measureUseCaseResultPositionZMm),
    csvFloatOrBlank(abs(measureUseCaseCurrentDeltaZMm)),
    csvFloatOrBlank(stiffnessValue)
  };
  return join(values, ";");
}

String getMeasureCsvFileLabel() {
  if (measureCsvPath.length() == 0) {
    return measureCsvFileName;
  }
  return new File(measureCsvPath).getName();
}

String measureCsvEscape(String rawValue) {
  if (rawValue == null) {
    return "";
  }

  String escaped = rawValue.replace("\"", "\"\"");
  if (escaped.indexOf(';') >= 0 || escaped.indexOf('"') >= 0 || escaped.indexOf('\n') >= 0) {
    return "\"" + escaped + "\"";
  }
  return escaped;
}
