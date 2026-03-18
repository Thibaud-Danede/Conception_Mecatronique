// ============================================================================
// Export CSV dedie au rendu Moodle.
//
// Ce module est distinct des CSV techniques du bridge:
// - robot_command.csv / robot_pose.csv restent reserves a la communication
// - moodle_force_positionz.csv sert au rendu / compte-rendu experimental
//
// Le format vise un vrai CSV de mesure, simple a rendre sur Moodle:
// - Timestamp
// - ForceN
// - PositionZ
// - StoppedByForceSensor
// ============================================================================

String moodleCsvPath = "";
String moodleCsvStatus = "CSV ready";
boolean moodleCsvRecording = false;
int moodleCsvRowsWritten = 0;
int moodleCsvLastSampleMs = -1000;

void setupMoodleCsvExport() {
  moodleCsvPath = sketchPath(moodleCsvFileName);
  moodleCsvStatus = "CSV ready -> " + getMoodleCsvFileLabel();
  moodleCsvRecording = false;
  moodleCsvRowsWritten = 0;
  moodleCsvLastSampleMs = -1000;

  if (moodleCsvAutoStartEnabled) {
    startMoodleCsvRecording();
  }
}

void updateMoodleCsvExport() {
  if (!moodleCsvRecording) {
    return;
  }

  int now = millis();
  if (now - moodleCsvLastSampleMs < max(20, moodleCsvSampleIntervalMs)) {
    return;
  }

  if (appendMoodleCsvSampleRow()) {
    moodleCsvLastSampleMs = now;
  }
}

void startMoodleCsvRecording() {
  if (moodleCsvRecording) {
    return;
  }

  if (!ensureMoodleCsvHeader()) {
    moodleCsvStatus = "header write failed";
    return;
  }

  moodleCsvRowsWritten = 0;
  moodleCsvLastSampleMs = -1000;
  moodleCsvRecording = true;
  moodleCsvStatus = "recording started";
}

void stopMoodleCsvRecording() {
  if (!moodleCsvRecording) {
    return;
  }

  moodleCsvRecording = false;
  moodleCsvStatus = "recording stopped";
}

void stopMoodleCsvRecordingOnDispose() {
  if (!moodleCsvRecording) {
    return;
  }

  moodleCsvRecording = false;
  moodleCsvStatus = "recording stopped on close";
}

void recordMoodleCsvEvent(String eventType) {
  if (!moodleCsvRecording) {
    return;
  }

  if (appendMoodleCsvSampleRow()) {
    moodleCsvLastSampleMs = millis();
    moodleCsvStatus = eventType + " sampled";
  }
}

boolean ensureMoodleCsvHeader() {
  if (moodleCsvPath.length() == 0) {
    return false;
  }

  String headerLine = buildMoodleCsvHeaderLine();
  File csvFile = new File(moodleCsvPath);
  if (csvFile.exists() && csvFile.length() > 0 && moodleCsvAppendToExistingFile) {
    String[] existingLines = readBridgeTextFile(moodleCsvPath);
    if (existingLines != null && existingLines.length > 0 && trim(existingLines[0]).equals(headerLine)) {
      return true;
    }
  }

  String[] lines = { headerLine };
  boolean writeOk = writeBridgeTextFileNow(moodleCsvPath, lines);
  if (writeOk) {
    moodleCsvStatus = "header reset to simple Moodle format";
  }
  return writeOk;
}

boolean appendMoodleCsvSampleRow() {
  if (moodleCsvPath.length() == 0) {
    return false;
  }

  if (!ensureMoodleCsvHeader()) {
    moodleCsvStatus = "header unavailable";
    return false;
  }

  try {
    File csvFile = new File(moodleCsvPath);
    File parentDir = csvFile.getParentFile();
    if (parentDir != null && !parentDir.exists()) {
      parentDir.mkdirs();
    }

    java.util.List<String> line = java.util.Collections.singletonList(buildMoodleCsvRowLine());
    java.nio.file.Files.write(
      csvFile.toPath(),
      line,
      java.nio.charset.StandardCharsets.UTF_8,
      java.nio.file.StandardOpenOption.CREATE,
      java.nio.file.StandardOpenOption.APPEND
    );

    moodleCsvRowsWritten++;
    moodleCsvStatus = "sample -> row " + moodleCsvRowsWritten;
    return true;
  } catch (Exception ex) {
    moodleCsvStatus = "append failed";
    return false;
  }
}

String buildMoodleCsvHeaderLine() {
  String[] columns = {
    "Timestamp",
    "ForceN",
    "PositionZ",
    "StoppedByForceSensor"
  };
  return join(columns, ",");
}

String buildMoodleCsvRowLine() {
  float forceN = isForceSensorFresh() ? getForceSensorValueN() : Float.NaN;
  float positionZ = hasLiveRobotPose ? liveCartesian[2] : Float.NaN;

  String[] values = {
    csvEscape(buildMoodleCsvTimestamp()),
    csvFloatOrBlank(forceN),
    csvFloatOrBlank(positionZ),
    csvBool(isForceSafetyStopLatched())
  };

  return join(values, ",");
}

String buildMoodleCsvTimestamp() {
  return year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) +
    "T" + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2) +
    "." + nf(millis() % 1000, 3);
}

String csvBool(boolean value) {
  return value ? "1" : "0";
}

String csvFloatOrBlank(float value) {
  if (Float.isNaN(value)) {
    return "";
  }
  return str(value);
}

String csvEscape(String rawValue) {
  if (rawValue == null) {
    return "";
  }

  String escaped = rawValue.replace("\"", "\"\"");
  if (escaped.indexOf(',') >= 0 || escaped.indexOf('"') >= 0 || escaped.indexOf('\n') >= 0) {
    return "\"" + escaped + "\"";
  }
  return escaped;
}

String getMoodleCsvFileLabel() {
  if (moodleCsvPath.length() == 0) {
    return moodleCsvFileName;
  }

  return new File(moodleCsvPath).getName();
}
