using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Threading;
using xARMForm;

namespace RobotPoseBridge
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            string configuredEndpoint = GetArgument(args, "--ip", "192.168.1.227");
            RobotEndpoint robotEndpoint = ParseRobotEndpoint(configuredEndpoint);
            string robotIp = robotEndpoint.Host;
            string poseFilePath = GetArgument(args, "--pose-file", Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "robot_pose.csv"));
            string commandFilePath = GetArgument(args, "--command-file", Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "robot_command.csv"));
            int pollMs = GetIntArgument(args, "--poll-ms", 200);
            float motionSpeed = GetFloatArgument(args, "--motion-speed", 3.0F);
            var bridgeState = new BridgeState();

            Directory.CreateDirectory(Path.GetDirectoryName(poseFilePath));
            Directory.CreateDirectory(Path.GetDirectoryName(commandFilePath));

            bool shouldStop = false;
            Console.CancelKeyPress += (sender, eventArgs) =>
            {
                shouldStop = true;
                eventArgs.Cancel = true;
            };

            var robot = new Robot();
            bool transportConnected = false;
            int lastProcessedSequence = GetLatestCommandSequence(commandFilePath);

            while (!shouldStop)
            {
                try
                {
                    if (!transportConnected)
                    {
                        UpdateConnectionDiagnostics(robotEndpoint, bridgeState);
                        transportConnected = robot.Create(robotIp);
                        if (!transportConnected)
                        {
                            bridgeState.DiagnosticSdkStatus = BuildSdkCreateFailureStatus(robot);
                            bridgeState.DiagnosticStatus = BuildDiagnosticSummary(bridgeState);
                            bridgeState.MarkDisconnected("sdk connection failed");
                            WritePoseFile(poseFilePath, false, robotEndpoint.DisplayValue, null, null, bridgeState);
                            Thread.Sleep(pollMs);
                            continue;
                        }

                        ConfigureRobotSession(robot, bridgeState);
                    }

                    float[] joints;
                    float[] cartesian;
                    transportConnected = TryReadRobotTelemetry(bridgeState, out joints, out cartesian);
                    bridgeState.DiagnosticStatus = BuildDiagnosticSummary(bridgeState);
                    WritePoseFile(poseFilePath, transportConnected, robotEndpoint.DisplayValue, joints, cartesian, bridgeState);
                    if (!transportConnected)
                    {
                        Thread.Sleep(pollMs);
                        continue;
                    }

                    RobotCommand command;
                    if (TryReadCommand(commandFilePath, lastProcessedSequence, out command))
                    {
                        ExecuteCommand(robot, command, bridgeState, motionSpeed);
                        lastProcessedSequence = command.Sequence;
                        bridgeState.DiagnosticStatus = BuildDiagnosticSummary(bridgeState);
                        WritePoseFile(poseFilePath, transportConnected, robotEndpoint.DisplayValue, joints, cartesian, bridgeState);
                    }
                }
                catch
                {
                    transportConnected = false;
                    bridgeState.MarkDisconnected("bridge read error");
                    bridgeState.DiagnosticSdkStatus = "bridge exception during robot communication";
                    bridgeState.DiagnosticStatus = BuildDiagnosticSummary(bridgeState);
                    bridgeState.CommandStatus = "bridge error";
                    WritePoseFile(poseFilePath, false, robotEndpoint.DisplayValue, null, null, bridgeState);
                }

                Thread.Sleep(pollMs);
            }

            return 0;
        }

        private static void ConfigureRobotSession(Robot robot, BridgeState bridgeState)
        {
            bridgeState.LastSimulationDisableRet = XArmAPI.set_simulation_robot(false);
            bridgeState.RobotModeStatus = bridgeState.LastSimulationDisableRet == 0
                ? "real requested"
                : $"real unavailable (simulation off ret {bridgeState.LastSimulationDisableRet})";

            bridgeState.LastSafetyEnableRet = robot.SetSelfCollision(true);
            bridgeState.IsSafetyReady = bridgeState.LastSafetyEnableRet == 0;
            bridgeState.SafetyStatus = bridgeState.IsSafetyReady
                ? "self collision enabled"
                : $"self collision unavailable ({bridgeState.LastSafetyEnableRet})";

            bridgeState.RobotStatus = "connected, checking real feedback";
            bridgeState.IsRealModeReady = false;
            bridgeState.DiagnosticSdkStatus = "SDK connected";
            bridgeState.ResetValidation();
        }

        private static bool TryReadRobotTelemetry(BridgeState bridgeState, out float[] joints, out float[] cartesian)
        {
            joints = new float[6];
            cartesian = new float[6];

            var jointBuffer = new float[7];
            var cartesianBuffer = new float[6];
            int state = -1;
            int poseRet = XArmAPI.get_position(cartesianBuffer);
            int stateRet = XArmAPI.get_state(ref state);

            if (poseRet != 0 || stateRet != 0)
            {
                bridgeState.DiagnosticSdkStatus = $"telemetry failed (pose {poseRet}, state {stateRet})";
                bridgeState.MarkDisconnected($"disconnected (pose {poseRet}, state {stateRet})");
                return false;
            }

            bridgeState.RobotStatus = $"connected (state {state})";

            int realJointRet = XArmAPI.get_servo_angle(jointBuffer, true);
            if (bridgeState.LastSimulationDisableRet == 0 && realJointRet == 0)
            {
                bridgeState.IsRealModeReady = true;
                bridgeState.RobotModeStatus = "real confirmed";
                bridgeState.DiagnosticSdkStatus = "SDK telemetry OK";
                joints = jointBuffer.Take(6).ToArray();
                cartesian = cartesianBuffer;
                return true;
            }

            bridgeState.IsRealModeReady = false;
            bridgeState.RobotModeStatus = bridgeState.LastSimulationDisableRet != 0
                ? $"real unavailable (simulation off ret {bridgeState.LastSimulationDisableRet})"
                : $"real unavailable (real joint ret {realJointRet})";
            bridgeState.DiagnosticSdkStatus = bridgeState.LastSimulationDisableRet != 0
                ? $"SDK connected, simulation off failed ({bridgeState.LastSimulationDisableRet})"
                : $"SDK connected, real joint read failed ({realJointRet})";
            return true;
        }

        private static void ExecuteCommand(Robot robot, RobotCommand command, BridgeState bridgeState, float motionSpeed)
        {
            if (command == null)
            {
                return;
            }

            bridgeState.LastCommandSequence = command.Sequence;
            bridgeState.LastCommandMode = command.Mode ?? string.Empty;

            if (string.Equals(command.Mode, "joints", StringComparison.OrdinalIgnoreCase))
            {
                if (!bridgeState.IsReadyForMotion)
                {
                    bridgeState.CommandStatus = "joint command blocked: " + bridgeState.GetMotionBlockReason();
                    return;
                }

                float[] jointTargets = new float[7];
                Array.Copy(command.Values, jointTargets, Math.Min(6, command.Values.Length));
                jointTargets[6] = 0.0F;
                PrepareRobotMotion(robot);
                int moveRet = robot.MoveJointValues(jointTargets, motionSpeed, wait: false);
                bridgeState.CommandStatus = moveRet == 0
                    ? $"joint command #{command.Sequence} sent"
                    : $"joint command #{command.Sequence} failed ({moveRet})";
                return;
            }

            if (string.Equals(command.Mode, "move_home", StringComparison.OrdinalIgnoreCase))
            {
                if (!bridgeState.IsReadyForMotion)
                {
                    bridgeState.CommandStatus = "home command blocked: " + bridgeState.GetMotionBlockReason();
                    return;
                }

                PrepareRobotMotion(robot);
                int moveHomeRet = robot.MoveHome(motionSpeed, 0, 0, false);
                bridgeState.CommandStatus = moveHomeRet == 0
                    ? $"home command #{command.Sequence} sent"
                    : $"home command #{command.Sequence} failed ({moveHomeRet})";
                return;
            }

            if (string.Equals(command.Mode, "stop_motion", StringComparison.OrdinalIgnoreCase))
            {
                int stopRet = robot.SetState(4);
                bridgeState.CommandStatus = stopRet == 0
                    ? $"stop command #{command.Sequence} sent"
                    : $"stop command #{command.Sequence} failed ({stopRet})";
                return;
            }

            if (string.Equals(command.Mode, "cartesian_ik_validate", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(command.Mode, "cartesian_ik_execute", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(command.Mode, "cartesian_ik", StringComparison.OrdinalIgnoreCase))
            {
                bool shouldExecute = !string.Equals(command.Mode, "cartesian_ik_validate", StringComparison.OrdinalIgnoreCase);
                ValidationResult validation = ValidateCartesianTarget(robot, command.Values, bridgeState);
                bridgeState.ApplyValidation(validation);

                if (!shouldExecute)
                {
                    bridgeState.CommandStatus = validation.IsValid
                        ? $"validation #{command.Sequence} ok"
                        : $"validation #{command.Sequence} blocked";
                    return;
                }

                if (!validation.IsValid)
                {
                    bridgeState.CommandStatus = $"execute #{command.Sequence} blocked";
                    return;
                }

                PrepareRobotMotion(robot);
                int moveRet = robot.MoveJointValues(validation.SolvedJoints, motionSpeed, wait: false);
                bridgeState.CommandStatus = moveRet == 0
                    ? $"MGI execute #{command.Sequence} sent"
                    : $"MGI execute #{command.Sequence} failed ({moveRet})";
                return;
            }

            bridgeState.CommandStatus = $"unsupported mode #{command.Sequence}: {command.Mode}";
        }

        private static void PrepareRobotMotion(Robot robot)
        {
            robot.EnableMotion(true);
            robot.SetMode(0);
            robot.SetState(0);
        }

        private static ValidationResult ValidateCartesianTarget(Robot robot, float[] rawValues, BridgeState bridgeState)
        {
            var targetPose = new float[6];
            if (rawValues != null)
            {
                Array.Copy(rawValues, targetPose, Math.Min(6, rawValues.Length));
            }

            var solvedAngles = new float[7];
            int ikRet = robot.GetInverseKinematics(targetPose, solvedAngles);
            if (ikRet != 0)
            {
                return ValidationResult.Invalid(targetPose, $"blocked: inverse kinematics failed ({ikRet})");
            }

            solvedAngles[6] = 0.0F;

            int jointLimit = 0;
            int jointLimitRet = XArmAPI.is_joint_limit(solvedAngles, ref jointLimit);
            if (jointLimitRet != 0)
            {
                return ValidationResult.Invalid(targetPose, $"blocked: joint limit check failed ({jointLimitRet})", solvedAngles);
            }

            if (jointLimit != 0)
            {
                return ValidationResult.Invalid(targetPose, "blocked: joint limit reached", solvedAngles);
            }

            int tcpLimit = 0;
            int tcpLimitRet = XArmAPI.is_tcp_limit(targetPose, ref tcpLimit);
            if (tcpLimitRet != 0)
            {
                return ValidationResult.Invalid(targetPose, $"blocked: tcp limit check failed ({tcpLimitRet})", solvedAngles);
            }

            if (tcpLimit != 0)
            {
                return ValidationResult.Invalid(targetPose, "blocked: tcp limit reached", solvedAngles);
            }

            if (!bridgeState.IsRealModeReady)
            {
                return ValidationResult.Invalid(targetPose, "blocked: real robot mode not confirmed", solvedAngles);
            }

            if (!bridgeState.IsSafetyReady)
            {
                return ValidationResult.Invalid(targetPose, "blocked: self collision detection unavailable", solvedAngles);
            }

            return ValidationResult.Valid(targetPose, solvedAngles, "validation ok");
        }

        private static bool TryReadCommand(string commandFilePath, int lastProcessedSequence, out RobotCommand command)
        {
            command = null;
            if (!File.Exists(commandFilePath))
            {
                return false;
            }

            string[] lines = File.ReadAllLines(commandFilePath);
            if (lines.Length == 0)
            {
                return false;
            }

            int sequence = 0;
            string mode = string.Empty;
            float[] values = null;

            foreach (string rawLine in lines)
            {
                string cleanLine = rawLine.Trim();
                if (cleanLine.Length == 0)
                {
                    continue;
                }

                string[] parts = cleanLine.Split(',');
                if (parts.Length < 2)
                {
                    continue;
                }

                string key = parts[0].Trim();
                if (string.Equals(key, "sequence", StringComparison.OrdinalIgnoreCase))
                {
                    int.TryParse(parts[1].Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out sequence);
                }
                else if (string.Equals(key, "mode", StringComparison.OrdinalIgnoreCase))
                {
                    mode = parts[1].Trim();
                }
                else if (string.Equals(key, "values", StringComparison.OrdinalIgnoreCase))
                {
                    values = parts.Skip(1).Select(part => ParseFloat(part, 0.0F)).ToArray();
                }
            }

            if (sequence <= lastProcessedSequence || values == null || values.Length < 6)
            {
                return false;
            }

            command = new RobotCommand
            {
                Sequence = sequence,
                Mode = mode,
                Values = values
            };
            return true;
        }

        private static int GetLatestCommandSequence(string commandFilePath)
        {
            if (!File.Exists(commandFilePath))
            {
                return 0;
            }

            try
            {
                string[] lines = File.ReadAllLines(commandFilePath);
                foreach (string rawLine in lines)
                {
                    string cleanLine = rawLine.Trim();
                    if (!cleanLine.StartsWith("sequence,", StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    string[] parts = cleanLine.Split(',');
                    if (parts.Length >= 2 && int.TryParse(parts[1].Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out int sequence))
                    {
                        return sequence;
                    }
                }
            }
            catch
            {
                return 0;
            }

            return 0;
        }

        private static void WritePoseFile(string poseFilePath, bool connected, string robotIp, float[] joints, float[] cartesian, BridgeState bridgeState)
        {
            float[] jointValues = connected && bridgeState.IsRealModeReady && joints != null ? joints : new float[6];
            float[] cartesianValues = connected && bridgeState.IsRealModeReady && cartesian != null ? cartesian : new float[6];

            string[] lines = new[]
            {
                "connected," + (connected ? "1" : "0"),
                "timestamp," + DateTime.Now.ToString("O", CultureInfo.InvariantCulture),
                "ip," + robotIp,
                "real_ready," + (bridgeState.IsRealModeReady ? "1" : "0"),
                "safety_ready," + (bridgeState.IsSafetyReady ? "1" : "0"),
                "joints," + string.Join(",", jointValues.Select(value => value.ToString(CultureInfo.InvariantCulture))),
                "cartesian," + string.Join(",", cartesianValues.Select(value => value.ToString(CultureInfo.InvariantCulture))),
                "robot_status," + bridgeState.RobotStatus,
                "robot_mode_status," + bridgeState.RobotModeStatus,
                "safety_status," + bridgeState.SafetyStatus,
                "diagnostic_status," + bridgeState.DiagnosticStatus,
                "diagnostic_network," + bridgeState.DiagnosticNetworkStatus,
                "diagnostic_sdk," + bridgeState.DiagnosticSdkStatus,
                "command_mode," + bridgeState.LastCommandMode,
                "command_sequence," + bridgeState.LastCommandSequence.ToString(CultureInfo.InvariantCulture),
                "command_status," + bridgeState.CommandStatus,
                "validation_valid," + (bridgeState.ValidationPassed ? "1" : "0"),
                "validation_status," + bridgeState.ValidationStatus,
                "validation_target," + string.Join(",", bridgeState.ValidationTarget.Select(value => value.ToString(CultureInfo.InvariantCulture))),
                "validation_joints," + string.Join(",", bridgeState.ValidationJoints.Select(value => value.ToString(CultureInfo.InvariantCulture))),
                "ik_valid," + (bridgeState.ValidationPassed ? "1" : "0"),
                "ik_joints," + string.Join(",", bridgeState.ValidationJoints.Select(value => value.ToString(CultureInfo.InvariantCulture)))
            };

            File.WriteAllLines(poseFilePath, lines);
        }

        private static string GetArgument(string[] args, string name, string fallback)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                {
                    return args[i + 1];
                }
            }

            return fallback;
        }

        private static int GetIntArgument(string[] args, string name, int fallback)
        {
            string rawValue = GetArgument(args, name, fallback.ToString(CultureInfo.InvariantCulture));
            if (int.TryParse(rawValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out int parsedValue))
            {
                return parsedValue;
            }

            return fallback;
        }

        private static float GetFloatArgument(string[] args, string name, float fallback)
        {
            string rawValue = GetArgument(args, name, fallback.ToString(CultureInfo.InvariantCulture));
            if (float.TryParse(rawValue, NumberStyles.Float, CultureInfo.InvariantCulture, out float parsedValue))
            {
                return parsedValue;
            }

            return fallback;
        }

        private static float ParseFloat(string rawValue, float fallback)
        {
            if (float.TryParse(rawValue.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out float parsedValue))
            {
                return parsedValue;
            }

            return fallback;
        }

        private static void UpdateConnectionDiagnostics(RobotEndpoint endpoint, BridgeState bridgeState)
        {
            if (endpoint.WebPort.HasValue)
            {
                bridgeState.DiagnosticNetworkStatus = TryOpenTcpPort(endpoint.Host, endpoint.WebPort.Value, 600)
                    ? $"web port {endpoint.WebPort.Value} reachable"
                    : $"web port {endpoint.WebPort.Value} unreachable";
            }
            else
            {
                bridgeState.DiagnosticNetworkStatus = "web port check skipped";
            }

            bridgeState.DiagnosticStatus = BuildDiagnosticSummary(bridgeState);
        }

        private static bool TryOpenTcpPort(string host, int port, int timeoutMs)
        {
            try
            {
                using (var client = new TcpClient())
                {
                    IAsyncResult result = client.BeginConnect(host, port, null, null);
                    bool connected = result.AsyncWaitHandle.WaitOne(timeoutMs);
                    if (!connected)
                    {
                        return false;
                    }

                    client.EndConnect(result);
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }

        private static string BuildSdkCreateFailureStatus(Robot robot)
        {
            if (robot.LastCreateInstanceId == -1)
            {
                return "SDK create_instance failed";
            }

            if (robot.LastSwitchRet != 0)
            {
                return $"SDK switch_xarm failed ({robot.LastSwitchRet})";
            }

            return "SDK connect failed";
        }

        private static string BuildDiagnosticSummary(BridgeState bridgeState)
        {
            if (bridgeState.IsRealModeReady && bridgeState.IsSafetyReady)
            {
                return "ready";
            }

            if (bridgeState.DiagnosticNetworkStatus.Contains("unreachable"))
            {
                return "network issue";
            }

            if (bridgeState.DiagnosticSdkStatus.Contains("failed"))
            {
                return "SDK issue";
            }

            if (!bridgeState.IsSafetyReady)
            {
                return "connected, safety degraded";
            }

            if (!bridgeState.IsRealModeReady)
            {
                return "connected, real mode degraded";
            }

            return "diagnostic pending";
        }

        private static RobotEndpoint ParseRobotEndpoint(string rawValue)
        {
            if (string.IsNullOrWhiteSpace(rawValue))
            {
                return new RobotEndpoint("192.168.1.227", "192.168.1.227", null);
            }

            string trimmed = rawValue.Trim();
            if (Uri.TryCreate(trimmed, UriKind.Absolute, out Uri uri))
            {
                return new RobotEndpoint(trimmed, uri.Host, uri.IsDefaultPort ? (int?)null : uri.Port);
            }

            if (trimmed.Contains(":"))
            {
                string[] parts = trimmed.Split(':');
                if (parts.Length >= 2)
                {
                    if (int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out int port))
                    {
                        return new RobotEndpoint(trimmed, parts[0], port);
                    }

                    return new RobotEndpoint(trimmed, parts[0], null);
                }
            }

            return new RobotEndpoint(trimmed, trimmed, null);
        }

        private sealed class RobotEndpoint
        {
            public RobotEndpoint(string displayValue, string host, int? webPort)
            {
                DisplayValue = displayValue;
                Host = host;
                WebPort = webPort;
            }

            public string DisplayValue { get; }

            public string Host { get; }

            public int? WebPort { get; }
        }

        private sealed class RobotCommand
        {
            public int Sequence { get; set; }

            public string Mode { get; set; }

            public float[] Values { get; set; }
        }

        private sealed class ValidationResult
        {
            public ValidationResult(float[] targetPose, float[] solvedJoints, bool isValid, string message)
            {
                TargetPose = new float[6];
                SolvedJoints = new float[7];
                Array.Copy(targetPose ?? new float[6], TargetPose, 6);
                if (solvedJoints != null)
                {
                    Array.Copy(solvedJoints, SolvedJoints, Math.Min(7, solvedJoints.Length));
                }

                IsValid = isValid;
                Message = message;
            }

            public float[] TargetPose { get; }

            public float[] SolvedJoints { get; }

            public bool IsValid { get; }

            public string Message { get; }

            public static ValidationResult Valid(float[] targetPose, float[] solvedJoints, string message)
            {
                return new ValidationResult(targetPose, solvedJoints, true, message);
            }

            public static ValidationResult Invalid(float[] targetPose, string message, float[] solvedJoints = null)
            {
                return new ValidationResult(targetPose, solvedJoints, false, message);
            }
        }

        private sealed class BridgeState
        {
            public BridgeState()
            {
                CommandStatus = "idle";
                LastCommandMode = "none";
                LastCommandSequence = 0;
                RobotStatus = "disconnected";
                RobotModeStatus = "real unavailable";
                SafetyStatus = "self collision unavailable";
                DiagnosticStatus = "diagnostic pending";
                DiagnosticNetworkStatus = "web port check pending";
                DiagnosticSdkStatus = "SDK check pending";
                ValidationStatus = "not validated";
                ValidationTarget = new float[6];
                ValidationJoints = new float[6];
            }

            public string CommandStatus { get; set; }

            public string LastCommandMode { get; set; }

            public int LastCommandSequence { get; set; }

            public string RobotStatus { get; set; }

            public string RobotModeStatus { get; set; }

            public string SafetyStatus { get; set; }

            public string DiagnosticStatus { get; set; }

            public string DiagnosticNetworkStatus { get; set; }

            public string DiagnosticSdkStatus { get; set; }

            public bool IsRealModeReady { get; set; }

            public bool IsSafetyReady { get; set; }

            public int LastSimulationDisableRet { get; set; }

            public int LastSafetyEnableRet { get; set; }

            public bool ValidationPassed { get; set; }

            public string ValidationStatus { get; set; }

            public float[] ValidationTarget { get; }

            public float[] ValidationJoints { get; }

            public bool IsReadyForMotion
            {
                get { return IsRealModeReady && IsSafetyReady; }
            }

            public void ResetValidation()
            {
                ValidationPassed = false;
                ValidationStatus = "not validated";
                Array.Clear(ValidationTarget, 0, ValidationTarget.Length);
                Array.Clear(ValidationJoints, 0, ValidationJoints.Length);
            }

            public void ApplyValidation(ValidationResult validation)
            {
                ValidationPassed = validation.IsValid;
                ValidationStatus = validation.Message;
                Array.Copy(validation.TargetPose, ValidationTarget, ValidationTarget.Length);
                for (int i = 0; i < ValidationJoints.Length; i++)
                {
                    ValidationJoints[i] = validation.SolvedJoints[i];
                }
            }

            public void MarkDisconnected(string status)
            {
                RobotStatus = status;
                RobotModeStatus = "real unavailable";
                IsRealModeReady = false;
            }

            public string GetMotionBlockReason()
            {
                if (!IsRealModeReady)
                {
                    return "real robot mode not confirmed";
                }

                if (!IsSafetyReady)
                {
                    return "self collision detection unavailable";
                }

                return "robot unavailable";
            }
        }
    }
}
