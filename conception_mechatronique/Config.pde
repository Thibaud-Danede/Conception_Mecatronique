float[] joint_min = {-180, -180, -180, -180, -180, -180};
float[] joint_max = {180, 180, 180, 180, 180, 180};
float[] cartesian_min = {-600, -600, -600, -180, -180, -180};
float[] cartesian_max = {600, 600, 600, 180, 180, 180};
float[] mgi_steps = {5, 5, 5, 5, 5, 5};

String bridgeTargetIp = "http://192.168.1.227:18333";
int bridgeLaunchPollMs = 60;
float bridgeMotionSpeed = 12.0;
boolean bridgeAutoStartEnabled = true;
boolean bridgeDiagnosticLogEnabled = false;
boolean bridgeKillStaleProcessesOnStart = true;
int bridgeStaleProcessKillWaitMs = 500;
String bridgeExecutableRelativePath = "RobotPoseBridge/bin/Debug_watchdog/RobotPoseBridge.exe";
String bridgeCommandFileName = "robot_command.csv";

// ===== Capteur HX711 / ESP32 =====
String forceSensorComPort = "COM4";
int forceSensorBaudRate = 115200;
boolean forceSensorAutoConnectOnManualTab = false;
int forceSensorPollIntervalMs = 80;
int forceSensorWarmupDelayMs = 1800;
boolean forceSensorAutoTareOnConnect = true;
int forceSensorAutoTareExtraDelayMs = 250;
int forceSensorDataTimeoutMs = 1500;
int forceSensorMaxLinesPerUpdate = 12;
int forceSensorMaxBufferedBytes = 2048;
boolean forceSensorAutoNudgeEnabled = true;
float forceSensorAutoNudgeDeadbandN = 1.0;
float forceSensorAutoNudgeHysteresisN = 0.25;
float forceSensorAutoNudgeVelocityMmSMin = 1.2;
float forceSensorAutoNudgeVelocityMmSMax = 20.0;
float forceSensorAutoNudgeForceForMaxSpeedN = 5.0;
float forceSensorAutoNudgeResponseExponent = 0.80;
int forceSensorAutoNudgeCommandIntervalMs = 30;
float forceSensorAutoNudgeFilterAlpha = 0.45;
boolean forceSensorAutoNudgeInvertDirection = false;
