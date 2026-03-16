float[] joint_min = {-180, -180, -180, -180, -180, -180};
float[] joint_max = {180, 180, 180, 180, 180, 180};
float[] cartesian_min = {-600, -600, -600, -180, -180, -180};
float[] cartesian_max = {600, 600, 600, 180, 180, 180};
float[] mgi_steps = {5, 5, 5, 5, 5, 5};

String bridgeTargetIp = "http://192.168.1.227:18333";
int bridgeLaunchPollMs = 200;
float bridgeMotionSpeed = 12.0;
boolean bridgeAutoStartEnabled = true;
String bridgeExecutableRelativePath = "RobotPoseBridge/bin/Debug/RobotPoseBridge.exe";
String bridgeCommandFileName = "robot_command.csv";

// ===== Capteur HX711 / ESP32 =====
String forceSensorComPort = "COM4";
int forceSensorBaudRate = 115200;
boolean forceSensorAutoConnectOnManualTab = true;
int forceSensorPollIntervalMs = 250;
int forceSensorWarmupDelayMs = 1800;
int forceSensorDataTimeoutMs = 1500;
int forceSensorMaxLinesPerUpdate = 12;
int forceSensorMaxBufferedBytes = 2048;
