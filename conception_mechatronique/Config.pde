// ============================================================================
// Configuration centralisee du sketch.
// Ce fichier ne contient pas de logique executable: il expose seulement des
// constantes et reglages relus par les autres modules.
//
// Les dependances principales sont:
// - RobotBridge.pde lit la cible IP, le binaire bridge, la cadence et la vitesse.
// - Robot3DView.pde lit les offsets/signes de calibration live -> modele.
// - ForceSensor.pde lit le port COM, les timings, les seuils et la loi d'auto-nudge.
// - MGI.pde et MGD.pde lisent les bornes min/max et les pas de variation.
// ============================================================================

// Bornes des articulations et de la cible cartesienne.
float[] joint_min = {-180, -180, -180, -180, -180, -180};
float[] joint_max = {180, 180, 180, 180, 180, 180};
float[] cartesian_min = {-600, -600, -600, -180, -180, -180};
float[] cartesian_max = {600, 600, 600, 180, 180, 180};
float[] mgi_steps = {5, 5, 5, 5, 5, 5};

// ===== Bridge robot =====
// Adresse web visible dans le navigateur; le bridge SDK en derive ensuite les
// connexions utiles. C'est aussi cette valeur qui est ecrite dans le CSV de
// telemetrie quand le robot n'est pas encore connecte.
String bridgeTargetIp = "http://192.168.1.227:18333";

// Frequence de polling cote sketch et vitesse par defaut transmise au bridge
// C#. Le bridge peut ensuite appliquer ses propres gardes-fous.
int bridgeLaunchPollMs = 60;
float bridgeMotionSpeed = 12.0;
boolean bridgeAutoStartEnabled = true;

// Outils de diagnostic et de nettoyage du bridge local. Le nettoyage stale
// sert surtout quand un ancien RobotPoseBridge.exe traine encore en memoire.
boolean bridgeDiagnosticLogEnabled = false;
boolean bridgeKillStaleProcessesOnStart = true;
int bridgeStaleProcessKillWaitMs = 500;

// Binaire lance par le sketch Processing. Le chemin est relatif au dossier du sketch.
String bridgeExecutableRelativePath = "RobotPoseBridge/bin/Debug_watchdog/RobotPoseBridge.exe";
String bridgeCommandFileName = "robot_command.csv";

// ===== Calibration visu 3D (reel -> modele) =====
// Ces coefficients sont appliques uniquement quand la pose live robot est
// disponible. Ils permettent de compenser une convention d'axes differente
// entre la telemetrie xArm et les OBJ de la vue 3D.
float[] robot3d_joint_sign = {1, -1, -1, 1, -1, 1};
float[] robot3d_joint_offset_deg = {0, 0, 0, 0, 0, 0};

// ===== Capteur HX711 / ESP32 =====
// Port serie et cadence de lecture du capteur de force. Processing lit ensuite
// le flux ligne par ligne via serialEvent().
String forceSensorComPort = "COM4";
int forceSensorBaudRate = 115200;
boolean forceSensorAutoConnectOnManualTab = false;
boolean forceSensorAutoConnectForSafetyStop = true;
int forceSensorPollIntervalMs = 80;
int forceSensorWarmupDelayMs = 1800;

// Tare automatique realisee apres la phase de boot du microcontroleur.
// Les limites de buffer evitent qu'un port bavard monopolise le sketch.
boolean forceSensorAutoTareOnConnect = true;
int forceSensorAutoTareExtraDelayMs = 250;
int forceSensorDataTimeoutMs = 1500;
int forceSensorMaxLinesPerUpdate = 12;
int forceSensorMaxBufferedBytes = 2048;

// Parametres du "force auto nudge": conversion force -> vitesse outil en Z.
// La chaine complete est:
// mesure capteur -> filtre -> deadband/hysteresis -> vitesse cible -> bridge.
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

// ===== Arret de securite base sur la force =====
// Interlock global actif hors onglet manuel: si la force depasse le seuil,
// un stop robot est demande puis le blocage reste latche jusqu'au reset explicite.
// Cette couche est distincte du "force auto nudge":
// - auto nudge = assistance de mouvement uniquement en controle manuel
// - safety stop = filet de securite global hors controle manuel
boolean forceSafetyStopEnabled = true;
float forceSafetyStopThresholdN = 2.0;
boolean forceSafetyStopUseAbsoluteValue = true;

// ===== CSV de rendu Moodle =====
// Export independant des CSV techniques du bridge.
String moodleCsvFileName = "moodle_force_positionz.csv";
int moodleCsvSampleIntervalMs = 100;
boolean moodleCsvAppendToExistingFile = true;
boolean moodleCsvAutoStartEnabled = true;

// ===== Use case "mesure" / rigidite plaque =====
// Ce mode est active depuis MGD/MGI et capture une reference force + position Z
// pour estimer ensuite une rigidite approchée |DeltaF| / |DeltaZ|.
boolean measureUseCaseAutoReconnectSensor = true;
float measureUseCaseContactForceThresholdN = 0.5;
float measureUseCaseTargetForceThresholdN = 5.0;
float measureUseCaseSafetyForceLimitN = 12.0;
float measureUseCaseMinDisplacementMm = 0.3;
int measureUseCaseSampleIntervalMs = 40;
boolean measureUseCaseAutoReleaseOnSafetyStop = true;
float measureUseCaseAutoReleaseDeltaMm = 8.0;
boolean measureUseCaseAutoReleaseInvertDirection = false;

// ===== CSV dedie au use case mesure =====
// Ce fichier est separe du CSV Moodle pour retrouver facilement les mesures
// de rigidite sans bruit diagnostic.
String measureCsvFileName = "measure_rigidity.csv";
boolean measureCsvAppendToExistingFile = true;
