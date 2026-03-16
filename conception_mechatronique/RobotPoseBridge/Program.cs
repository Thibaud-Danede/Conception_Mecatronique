using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using xARMForm;

namespace RobotPoseBridge
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            string robotIp = NormalizeRobotEndpoint(GetArgument(args, "--ip", "192.168.1.227"));
            string poseFilePath = GetArgument(args, "--pose-file", Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "robot_pose.csv"));
            string commandFilePath = GetArgument(args, "--command-file", Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "robot_command.csv"));
            int pollMs = GetIntArgument(args, "--poll-ms", 200);

            Directory.CreateDirectory(Path.GetDirectoryName(poseFilePath));
            Directory.CreateDirectory(Path.GetDirectoryName(commandFilePath));

            bool shouldStop = false;
            Console.CancelKeyPress += (sender, eventArgs) =>
            {
                shouldStop = true;
                eventArgs.Cancel = true;
            };

            var robot = new Robot();
            bool connected = false;
            int lastProcessedSequence = GetLatestCommandSequence(commandFilePath);

            while (!shouldStop)
            {
                try
                {
                    if (!connected)
                    {
                        connected = robot.Create(robotIp);
                        if (!connected)
                        {
                            WritePoseFile(poseFilePath, false, robotIp, null, null);
                            Thread.Sleep(pollMs);
                            continue;
                        }
                    }

                    float[] joints = robot.GetCurrentJoint().Take(6).ToArray();
                    float[] cartesian = robot.GetCurrentPosition().ToArray();
                    WritePoseFile(poseFilePath, true, robotIp, joints, cartesian);

                    RobotCommand command;
                    if (TryReadCommand(commandFilePath, lastProcessedSequence, out command))
                    {
                        ExecuteCommand(robot, command);
                        lastProcessedSequence = command.Sequence;
                    }
                }
                catch
                {
                    connected = false;
                    WritePoseFile(poseFilePath, false, robotIp, null, null);
                }

                Thread.Sleep(pollMs);
            }

            return 0;
        }

        private static void ExecuteCommand(Robot robot, RobotCommand command)
        {
            if (command == null)
            {
                return;
            }

            robot.EnableMotion(true);
            robot.SetMode(0);
            robot.SetState(0);

            if (string.Equals(command.Mode, "joints", StringComparison.OrdinalIgnoreCase))
            {
                float[] jointTargets = new float[7];
                Array.Copy(command.Values, jointTargets, Math.Min(6, command.Values.Length));
                jointTargets[6] = 0.0F;
                robot.MoveJointValues(jointTargets, wait: false);
            }
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
                    values = parts
                        .Skip(1)
                        .Select(part => ParseFloat(part, 0.0F))
                        .ToArray();
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

        private static void WritePoseFile(string poseFilePath, bool connected, string robotIp, float[] joints, float[] cartesian)
        {
            string[] lines = connected
                ? new[]
                {
                    "connected,1",
                    "timestamp," + DateTime.Now.ToString("O", CultureInfo.InvariantCulture),
                    "ip," + robotIp,
                    "joints," + string.Join(",", joints.Select(value => value.ToString(CultureInfo.InvariantCulture))),
                    "cartesian," + string.Join(",", cartesian.Select(value => value.ToString(CultureInfo.InvariantCulture)))
                }
                : new[]
                {
                    "connected,0",
                    "timestamp," + DateTime.Now.ToString("O", CultureInfo.InvariantCulture),
                    "ip," + robotIp,
                    "joints,0,0,0,0,0,0",
                    "cartesian,0,0,0,0,0,0"
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

        private static float ParseFloat(string rawValue, float fallback)
        {
            if (float.TryParse(rawValue.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out float parsedValue))
            {
                return parsedValue;
            }

            return fallback;
        }

        private static string NormalizeRobotEndpoint(string rawValue)
        {
            if (string.IsNullOrWhiteSpace(rawValue))
            {
                return "192.168.1.227";
            }

            string trimmed = rawValue.Trim();
            if (Uri.TryCreate(trimmed, UriKind.Absolute, out Uri uri))
            {
                return uri.Host;
            }

            if (trimmed.Contains(":"))
            {
                string[] parts = trimmed.Split(':');
                if (parts.Length >= 2)
                {
                    return parts[0];
                }
            }

            return trimmed;
        }

        private sealed class RobotCommand
        {
            public int Sequence { get; set; }

            public string Mode { get; set; }

            public float[] Values { get; set; }
        }
    }
}
