using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace xARMForm
{
    public partial class Form1 : Form
    {
        private static readonly Regex ForceRegex = new Regex(
            @"Reading:\s*(?<value>[-+]?\d+(?:[.,]\d+)?)\s*(?<unit>[A-Za-z]+)?",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        private readonly Robot xARM;
        private readonly SerialPort forceSensorPort;
        private readonly List<ForceSample> forceSamples;
        private readonly StringBuilder serialBuffer;
        private readonly Timer poseExportTimer;
        private readonly string sharedPoseFilePath;

        private ComboBox comboBoxSerialPort;
        private ComboBox comboBoxBaudRate;
        private Button buttonRefreshPorts;
        private Button buttonOpenSerial;
        private Button buttonCloseSerial;
        private Button buttonSendSerial;
        private Button buttonMeasureForce;
        private Button buttonSelectCsv;
        private Button buttonSaveCsv;
        private TextBox textBoxSerialCommand;
        private TextBox textBoxSerialLog;
        private TextBox textBoxLatestForce;
        private TextBox textBoxTargetForce;
        private TextBox textBoxGain;
        private TextBox textBoxMaxStep;
        private TextBox textBoxCsvPath;
        private Label labelSerialState;

        private bool awaitingForceMeasurement;
        private bool autoMoveAfterMeasurement;
        private float lastForceValue;
        private string lastForceUnit = string.Empty;

        public Form1()
        {
            InitializeComponent();

            xARM = new Robot();
            forceSensorPort = new SerialPort
            {
                BaudRate = 115200,
                DataBits = 8,
                Parity = Parity.None,
                StopBits = StopBits.One,
                NewLine = "\n"
            };
            forceSensorPort.DataReceived += ForceSensorPort_DataReceived;

            forceSamples = new List<ForceSample>();
            serialBuffer = new StringBuilder();
            sharedPoseFilePath = ResolveSharedPoseFilePath();
            poseExportTimer = new Timer();
            poseExportTimer.Interval = 200;
            poseExportTimer.Tick += PoseExportTimer_Tick;
            poseExportTimer.Start();

            BuildForceUi();
            RefreshSerialPorts();

            comboBoxSetCollisionSensitivity.SelectedIndex = 3;
            timerCMD.Interval = 300;
            Text = "xARM Force Integration";
            ClientSize = new Size(1160, 520);
            MinimumSize = new Size(1176, 559);

            UpdateForceUiState();
        }

        private void BuildForceUi()
        {
            var groupBoxSensor = new GroupBox
            {
                Text = "Force Sensor + CSV",
                Location = new Point(730, 20),
                Size = new Size(410, 470)
            };

            var labelPort = new Label
            {
                AutoSize = true,
                Location = new Point(16, 30),
                Text = "Port"
            };
            comboBoxSerialPort = new ComboBox
            {
                DropDownStyle = ComboBoxStyle.DropDownList,
                Location = new Point(60, 26),
                Size = new Size(100, 21)
            };

            buttonRefreshPorts = new Button
            {
                Location = new Point(170, 24),
                Size = new Size(70, 24),
                Text = "Refresh"
            };
            buttonRefreshPorts.Click += ButtonRefreshPorts_Click;

            var labelBaud = new Label
            {
                AutoSize = true,
                Location = new Point(252, 30),
                Text = "Baud"
            };
            comboBoxBaudRate = new ComboBox
            {
                DropDownStyle = ComboBoxStyle.DropDownList,
                Location = new Point(295, 26),
                Size = new Size(95, 21)
            };
            comboBoxBaudRate.Items.AddRange(new object[] { "115200", "38400", "19200", "9600" });
            comboBoxBaudRate.SelectedIndex = 0;

            buttonOpenSerial = new Button
            {
                Location = new Point(16, 58),
                Size = new Size(80, 26),
                Text = "Open"
            };
            buttonOpenSerial.Click += ButtonOpenSerial_Click;

            buttonCloseSerial = new Button
            {
                Location = new Point(104, 58),
                Size = new Size(80, 26),
                Text = "Close"
            };
            buttonCloseSerial.Click += ButtonCloseSerial_Click;

            labelSerialState = new Label
            {
                AutoSize = true,
                Location = new Point(196, 64),
                Text = "Closed"
            };

            var labelCommand = new Label
            {
                AutoSize = true,
                Location = new Point(16, 99),
                Text = "Command"
            };
            textBoxSerialCommand = new TextBox
            {
                Location = new Point(80, 96),
                Size = new Size(50, 20),
                Text = "M"
            };

            buttonSendSerial = new Button
            {
                Location = new Point(138, 94),
                Size = new Size(70, 24),
                Text = "Send"
            };
            buttonSendSerial.Click += ButtonSendSerial_Click;

            buttonMeasureForce = new Button
            {
                Location = new Point(216, 94),
                Size = new Size(85, 24),
                Text = "Measure"
            };
            buttonMeasureForce.Click += ButtonMeasureForce_Click;

            var labelLatestForce = new Label
            {
                AutoSize = true,
                Location = new Point(16, 132),
                Text = "Latest force"
            };
            textBoxLatestForce = new TextBox
            {
                Location = new Point(95, 129),
                Size = new Size(100, 20),
                ReadOnly = true
            };

            var labelTargetForce = new Label
            {
                AutoSize = true,
                Location = new Point(16, 164),
                Text = "Target"
            };
            textBoxTargetForce = new TextBox
            {
                Location = new Point(60, 161),
                Size = new Size(55, 20),
                Text = "0"
            };

            var labelGain = new Label
            {
                AutoSize = true,
                Location = new Point(131, 164),
                Text = "Gain mm/unit"
            };
            textBoxGain = new TextBox
            {
                Location = new Point(220, 161),
                Size = new Size(55, 20),
                Text = "0.5"
            };

            var labelMaxStep = new Label
            {
                AutoSize = true,
                Location = new Point(292, 164),
                Text = "Max"
            };
            textBoxMaxStep = new TextBox
            {
                Location = new Point(328, 161),
                Size = new Size(50, 20),
                Text = "2.0"
            };

            Controls.Add(groupBoxSensor);

            buttonTimer.Parent = groupBoxSensor;
            buttonTimer.Location = new Point(16, 195);
            buttonTimer.Size = new Size(150, 28);
            buttonTimer.Text = "Start Force Loop";

            var labelTimerHint = new Label
            {
                AutoSize = true,
                Location = new Point(180, 202),
                Text = "Timer = 300 ms"
            };

            var labelCsv = new Label
            {
                AutoSize = true,
                Location = new Point(16, 240),
                Text = "CSV"
            };
            textBoxCsvPath = new TextBox
            {
                Location = new Point(50, 237),
                Size = new Size(255, 20),
                ReadOnly = true
            };

            buttonSelectCsv = new Button
            {
                Location = new Point(313, 235),
                Size = new Size(75, 24),
                Text = "Select"
            };
            buttonSelectCsv.Click += ButtonSelectCsv_Click;

            buttonSaveCsv = new Button
            {
                Location = new Point(313, 266),
                Size = new Size(75, 24),
                Text = "Save CSV"
            };
            buttonSaveCsv.Click += ButtonSaveCsv_Click;

            var labelLog = new Label
            {
                AutoSize = true,
                Location = new Point(16, 272),
                Text = "Serial log"
            };
            textBoxSerialLog = new TextBox
            {
                Location = new Point(16, 296),
                Size = new Size(372, 154),
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical
            };

            groupBoxSensor.Controls.Add(labelPort);
            groupBoxSensor.Controls.Add(comboBoxSerialPort);
            groupBoxSensor.Controls.Add(buttonRefreshPorts);
            groupBoxSensor.Controls.Add(labelBaud);
            groupBoxSensor.Controls.Add(comboBoxBaudRate);
            groupBoxSensor.Controls.Add(buttonOpenSerial);
            groupBoxSensor.Controls.Add(buttonCloseSerial);
            groupBoxSensor.Controls.Add(labelSerialState);
            groupBoxSensor.Controls.Add(labelCommand);
            groupBoxSensor.Controls.Add(textBoxSerialCommand);
            groupBoxSensor.Controls.Add(buttonSendSerial);
            groupBoxSensor.Controls.Add(buttonMeasureForce);
            groupBoxSensor.Controls.Add(labelLatestForce);
            groupBoxSensor.Controls.Add(textBoxLatestForce);
            groupBoxSensor.Controls.Add(labelTargetForce);
            groupBoxSensor.Controls.Add(textBoxTargetForce);
            groupBoxSensor.Controls.Add(labelGain);
            groupBoxSensor.Controls.Add(textBoxGain);
            groupBoxSensor.Controls.Add(labelMaxStep);
            groupBoxSensor.Controls.Add(textBoxMaxStep);
            groupBoxSensor.Controls.Add(labelTimerHint);
            groupBoxSensor.Controls.Add(labelCsv);
            groupBoxSensor.Controls.Add(textBoxCsvPath);
            groupBoxSensor.Controls.Add(buttonSelectCsv);
            groupBoxSensor.Controls.Add(buttonSaveCsv);
            groupBoxSensor.Controls.Add(labelLog);
            groupBoxSensor.Controls.Add(textBoxSerialLog);
        }

        private void ButtonCreateARM_Click(object sender, EventArgs e)
        {
            string ip = textBoxIPAdress.Text;
            xARM.Create(ip);
            if (xARM.IsCreated())
            {
                buttonMotionARM.Enabled = true;
                xARM.GetVersion();
                AppendSerialLog("Robot connected to " + ip + Environment.NewLine);
            }

            UpdateForceUiState();
        }

        private void ButtonMotionARM_Click(object sender, EventArgs e)
        {
            int ret;
            if (xARM.IsEnableMotion())
            {
                ret = xARM.EnableMotion(false);
                buttonGetCollisionSensitivity.Enabled = false;
                buttonSetCollisionSensitivity.Enabled = false;
                buttonSelfCollision.Enabled = false;
                buttonGetJoint.Enabled = false;
                buttonGetPosition.Enabled = false;
                buttonGetBase.Enabled = false;
                buttonGetTCP.Enabled = false;
                buttonMoveBase.Enabled = false;
                buttonMoveTCP.Enabled = false;
                buttonMoveAngle.Enabled = false;
                buttonMoveHome.Enabled = false;
            }
            else
            {
                ret = xARM.EnableMotion(true);
                if (ret == 0)
                {
                    xARM.SetMode(0);
                    xARM.SetState(0);
                    buttonResetARM.Enabled = true;
                }
                else
                {
                    buttonResetARM.Enabled = false;
                }
            }

            UpdateForceUiState();
        }

        private void ButtonResetARM_Click(object sender, EventArgs e)
        {
            xARM.Reset();

            buttonGetCollisionSensitivity.Enabled = true;
            buttonSetCollisionSensitivity.Enabled = true;
            buttonSelfCollision.Enabled = true;
            buttonGetJoint.Enabled = true;
            buttonGetPosition.Enabled = true;
            buttonGetBase.Enabled = true;
            buttonGetTCP.Enabled = true;
            buttonMoveBase.Enabled = true;
            buttonMoveTCP.Enabled = true;
            buttonMoveAngle.Enabled = true;
            buttonMoveHome.Enabled = true;

            UpdateForceUiState();
        }

        private void ButtonGetJoint_Click(object sender, EventArgs e)
        {
            float[] joint = xARM.GetCurrentJoint();
            textBoxJoint.Text = string.Join(" | ", joint.Take(6).Select(value => value.ToString("F", CultureInfo.InvariantCulture)));
            textBoxJoint.Update();
        }

        private void ButtonGetPosition_Click(object sender, EventArgs e)
        {
            float[] pose = xARM.GetCurrentPosition();
            textBoxPosition.Text = string.Join(" | ", pose.Select(value => value.ToString("F", CultureInfo.InvariantCulture)));
            textBoxPosition.Update();
        }

        private void ButtonGetTCP_Click(object sender, EventArgs e)
        {
            float[] frame = xARM.GetTCP();
            textBoxTCP.Text = string.Join(" | ", frame.Select(value => value.ToString("F", CultureInfo.InvariantCulture)));
            textBoxTCP.Update();
        }

        private void ButtonGetBase_Click(object sender, EventArgs e)
        {
            float[] frame = xARM.GetBase();
            textBoxBase.Text = string.Join(" | ", frame.Select(value => value.ToString("F", CultureInfo.InvariantCulture)));
            textBoxBase.Update();
        }

        private void ButtonMoveBase_Click(object sender, EventArgs e)
        {
            float[] pose = { 300, 0, 200, 180, 0, 0 };
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveBase(pose, true);
                RefreshRobotReadouts(sender, e);
            }
        }

        private void ButtonMoveTCP_Click(object sender, EventArgs e)
        {
            float[] pose = { 0, 0, 20, 0, 0, 0 };
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveTool(pose, true);
                RefreshRobotReadouts(sender, e);
            }
        }

        private void ButtonMoveAngle_Click(object sender, EventArgs e)
        {
            float[] angles = xARM.GetCurrentJoint();
            angles[0] += 10.0F;
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveJointValues(angles);
                RefreshRobotReadouts(sender, e);
            }
        }

        private void ButtonMoveHome_Click(object sender, EventArgs e)
        {
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveHome(0, 0, 0, true);
                RefreshRobotReadouts(sender, e);
            }
        }

        private void ButtonGetCollisionSensitivity_Click(object sender, EventArgs e)
        {
            if (xARM.IsCreated())
            {
                int sens = xARM.GetCollisionSensitivity();
                textBoxCollitionSensitivity.Text = sens.ToString(CultureInfo.InvariantCulture);
                textBoxCollitionSensitivity.Update();
                comboBoxSetCollisionSensitivity.SelectedIndex = sens;
            }
        }

        private void ButtonSetCollisionSensitivity_Click(object sender, EventArgs e)
        {
            if (xARM.IsCreated())
            {
                int sens = comboBoxSetCollisionSensitivity.SelectedIndex;
                textBoxCollitionSensitivity.Text = sens.ToString(CultureInfo.InvariantCulture);
                textBoxCollitionSensitivity.Update();
                xARM.SetCollisionSensitivity(sens);
            }
        }

        private void ButtonSelfCollision_Click(object sender, EventArgs e)
        {
            if (xARM.IsCreated())
            {
                if (xARM.GetSelfCollision())
                {
                    xARM.SetSelfCollision(false);
                    checkBoxSelfCollision.Checked = false;
                }
                else
                {
                    xARM.SetSelfCollision(true);
                    checkBoxSelfCollision.Checked = true;
                }
            }
        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            timerCMD.Stop();
            poseExportTimer.Stop();

            if (forceSensorPort.IsOpen)
            {
                forceSensorPort.Close();
            }

            forceSensorPort.Dispose();

            if (xARM.IsCreated())
            {
                xARM.EnableMotion(false);
            }
        }

        private void timerCMD_Tick(object sender, EventArgs e)
        {
            if (!forceSensorPort.IsOpen || !xARM.IsCreated() || !xARM.IsEnableMotion())
            {
                StopForceLoop();
                return;
            }

            if (awaitingForceMeasurement)
            {
                return;
            }

            RequestForceMeasurement(true);
        }

        private void ButtonTimer_Click(object sender, EventArgs e)
        {
            if (timerCMD.Enabled)
            {
                StopForceLoop();
                return;
            }

            if (!forceSensorPort.IsOpen)
            {
                MessageBox.Show("Open the serial port before starting the force loop.");
                return;
            }

            if (!xARM.IsCreated() || !xARM.IsEnableMotion())
            {
                MessageBox.Show("Connect the robot and enable motion before starting the force loop.");
                return;
            }

            timerCMD.Start();
            buttonTimer.Text = "Stop Force Loop";
            AppendSerialLog("Force loop started" + Environment.NewLine);
        }

        private void ButtonRefreshPorts_Click(object sender, EventArgs e)
        {
            RefreshSerialPorts();
            UpdateForceUiState();
        }

        private void ButtonOpenSerial_Click(object sender, EventArgs e)
        {
            if (comboBoxSerialPort.SelectedItem == null)
            {
                MessageBox.Show("Select a serial port first.");
                return;
            }

            if (forceSensorPort.IsOpen)
            {
                return;
            }

            forceSensorPort.PortName = comboBoxSerialPort.SelectedItem.ToString();
            forceSensorPort.BaudRate = int.Parse(comboBoxBaudRate.SelectedItem.ToString(), CultureInfo.InvariantCulture);

            try
            {
                forceSensorPort.Open();
                serialBuffer.Clear();
                AppendSerialLog("Serial port opened: " + forceSensorPort.PortName + Environment.NewLine);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Unable to open the serial port: " + ex.Message);
            }

            UpdateForceUiState();
        }

        private void ButtonCloseSerial_Click(object sender, EventArgs e)
        {
            StopForceLoop();

            if (!forceSensorPort.IsOpen)
            {
                return;
            }

            forceSensorPort.Close();
            AppendSerialLog("Serial port closed" + Environment.NewLine);
            UpdateForceUiState();
        }

        private void ButtonSendSerial_Click(object sender, EventArgs e)
        {
            SendSerialCommand(textBoxSerialCommand.Text);
        }

        private void ButtonMeasureForce_Click(object sender, EventArgs e)
        {
            RequestForceMeasurement(false);
        }

        private void ButtonSelectCsv_Click(object sender, EventArgs e)
        {
            using (var dialog = new SaveFileDialog())
            {
                dialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*";
                dialog.FileName = "force_log_" + DateTime.Now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture) + ".csv";
                dialog.InitialDirectory = Application.StartupPath;

                if (dialog.ShowDialog(this) == DialogResult.OK)
                {
                    textBoxCsvPath.Text = dialog.FileName;
                }
            }
        }

        private void ButtonSaveCsv_Click(object sender, EventArgs e)
        {
            SaveSamplesToCsv();
        }

        private void ForceSensorPort_DataReceived(object sender, SerialDataReceivedEventArgs e)
        {
            string data;

            try
            {
                data = forceSensorPort.ReadExisting();
            }
            catch
            {
                return;
            }

            if (string.IsNullOrEmpty(data) || !IsHandleCreated || IsDisposed)
            {
                return;
            }

            BeginInvoke(new Action<string>(HandleSerialData), data);
        }

        private void HandleSerialData(string data)
        {
            AppendSerialLog(data);
            serialBuffer.Append(data);

            string current = serialBuffer.ToString();
            int lastLineBreak = Math.Max(current.LastIndexOf('\n'), current.LastIndexOf('\r'));
            if (lastLineBreak < 0)
            {
                return;
            }

            string completeText = current.Substring(0, lastLineBreak + 1);
            string remaining = current.Substring(lastLineBreak + 1);

            serialBuffer.Clear();
            serialBuffer.Append(remaining);

            string[] lines = completeText.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string line in lines.Select(item => item.Trim()).Where(item => item.Length > 0))
            {
                ProcessSensorLine(line);
            }
        }

        private void ProcessSensorLine(string line)
        {
            Match match = ForceRegex.Match(line);
            if (!match.Success)
            {
                return;
            }

            awaitingForceMeasurement = false;

            string forceText = match.Groups["value"].Value.Replace(',', '.');
            if (!float.TryParse(forceText, NumberStyles.Float, CultureInfo.InvariantCulture, out float forceValue))
            {
                return;
            }

            lastForceValue = forceValue;
            lastForceUnit = match.Groups["unit"].Success ? match.Groups["unit"].Value : string.Empty;
            textBoxLatestForce.Text = string.Format(
                CultureInfo.InvariantCulture,
                "{0:F3} {1}",
                lastForceValue,
                lastForceUnit).Trim();

            float deltaZ = 0.0F;
            if (autoMoveAfterMeasurement)
            {
                autoMoveAfterMeasurement = false;
                deltaZ = ComputeDeltaZ(forceValue);
                ApplyToolDeltaZ(deltaZ);
            }

            AddSample(forceValue, lastForceUnit, deltaZ);
            UpdateForceUiState();
        }

        private void RefreshSerialPorts()
        {
            string selectedPort = comboBoxSerialPort.SelectedItem as string;
            string[] ports = SerialPort.GetPortNames().OrderBy(port => port).ToArray();

            comboBoxSerialPort.Items.Clear();
            comboBoxSerialPort.Items.AddRange(ports);

            if (!string.IsNullOrEmpty(selectedPort) && ports.Contains(selectedPort))
            {
                comboBoxSerialPort.SelectedItem = selectedPort;
            }
            else if (ports.Length > 0)
            {
                comboBoxSerialPort.SelectedIndex = 0;
            }
        }

        private void SendSerialCommand(string command)
        {
            if (!forceSensorPort.IsOpen)
            {
                MessageBox.Show("Open the serial port before sending a command.");
                return;
            }

            if (string.IsNullOrWhiteSpace(command))
            {
                return;
            }

            try
            {
                forceSensorPort.Write(command.Trim());
                AppendSerialLog("> " + command.Trim() + Environment.NewLine);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Unable to send the serial command: " + ex.Message);
            }
        }

        private void RequestForceMeasurement(bool moveAfterMeasure)
        {
            if (!forceSensorPort.IsOpen)
            {
                MessageBox.Show("Open the serial port before requesting a measurement.");
                return;
            }

            if (awaitingForceMeasurement)
            {
                return;
            }

            awaitingForceMeasurement = true;
            autoMoveAfterMeasurement = moveAfterMeasure;
            SendSerialCommand("M");
        }

        private float ComputeDeltaZ(float forceValue)
        {
            float targetForce = ReadFloatFromTextBox(textBoxTargetForce, 0.0F);
            float gain = ReadFloatFromTextBox(textBoxGain, 0.5F);
            float maxStep = Math.Abs(ReadFloatFromTextBox(textBoxMaxStep, 2.0F));

            float deltaZ = (targetForce - forceValue) * gain;
            if (deltaZ > maxStep)
            {
                deltaZ = maxStep;
            }
            else if (deltaZ < -maxStep)
            {
                deltaZ = -maxStep;
            }

            return deltaZ;
        }

        private void ApplyToolDeltaZ(float deltaZ)
        {
            if (Math.Abs(deltaZ) < 0.0001F)
            {
                return;
            }

            if (!xARM.IsCreated() || !xARM.IsEnableMotion())
            {
                return;
            }

            float[] pose = { 0.0F, 0.0F, deltaZ, 0.0F, 0.0F, 0.0F };
            xARM.MoveTool(pose, true);
            RefreshRobotReadouts(this, EventArgs.Empty);
        }

        private void AddSample(float forceValue, string unit, float deltaZ)
        {
            float[] pose = null;
            if (xARM.IsCreated())
            {
                pose = xARM.GetCurrentPosition().ToArray();
            }

            forceSamples.Add(new ForceSample
            {
                Timestamp = DateTime.Now,
                Force = forceValue,
                Unit = unit,
                DeltaZ = deltaZ,
                X = pose != null ? pose[0] : float.NaN,
                Y = pose != null ? pose[1] : float.NaN,
                Z = pose != null ? pose[2] : float.NaN,
                Roll = pose != null ? pose[3] : float.NaN,
                Pitch = pose != null ? pose[4] : float.NaN,
                Yaw = pose != null ? pose[5] : float.NaN
            });
        }

        private void SaveSamplesToCsv()
        {
            if (forceSamples.Count == 0)
            {
                MessageBox.Show("No measurements available to save.");
                return;
            }

            if (string.IsNullOrWhiteSpace(textBoxCsvPath.Text))
            {
                ButtonSelectCsv_Click(this, EventArgs.Empty);
                if (string.IsNullOrWhiteSpace(textBoxCsvPath.Text))
                {
                    return;
                }
            }

            var lines = new List<string>
            {
                "timestamp,force,unit,deltaZ,x,y,z,roll,pitch,yaw"
            };
            lines.AddRange(forceSamples.Select(sample => sample.ToCsvLine()));

            try
            {
                File.WriteAllLines(textBoxCsvPath.Text, lines);
                MessageBox.Show("CSV saved to " + textBoxCsvPath.Text);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Unable to save the CSV file: " + ex.Message);
            }
        }

        private void StopForceLoop()
        {
            timerCMD.Stop();
            awaitingForceMeasurement = false;
            autoMoveAfterMeasurement = false;
            buttonTimer.Text = "Start Force Loop";
            UpdateForceUiState();
        }

        private void RefreshRobotReadouts(object sender, EventArgs e)
        {
            ButtonGetJoint_Click(sender, e);
            ButtonGetPosition_Click(sender, e);
            ExportCurrentPoseSnapshot();
        }

        private void AppendSerialLog(string message)
        {
            if (string.IsNullOrEmpty(message))
            {
                return;
            }

            textBoxSerialLog.AppendText(message);
            textBoxSerialLog.SelectionStart = textBoxSerialLog.TextLength;
            textBoxSerialLog.ScrollToCaret();
        }

        private void UpdateForceUiState()
        {
            bool serialOpen = forceSensorPort.IsOpen;
            bool robotReady = xARM.IsCreated() && xARM.IsEnableMotion();

            if ((!serialOpen || !robotReady) && timerCMD.Enabled)
            {
                StopForceLoop();
                return;
            }

            buttonOpenSerial.Enabled = !serialOpen && comboBoxSerialPort.Items.Count > 0;
            buttonCloseSerial.Enabled = serialOpen;
            buttonSendSerial.Enabled = serialOpen;
            buttonMeasureForce.Enabled = serialOpen;
            buttonTimer.Enabled = serialOpen && robotReady;
            buttonSaveCsv.Enabled = forceSamples.Count > 0;

            labelSerialState.Text = serialOpen
                ? "Open: " + forceSensorPort.PortName
                : "Closed";
        }

        private static float ReadFloatFromTextBox(TextBox textBox, float fallbackValue)
        {
            string normalized = textBox.Text.Replace(',', '.');
            if (float.TryParse(normalized, NumberStyles.Float, CultureInfo.InvariantCulture, out float value))
            {
                return value;
            }

            return fallbackValue;
        }

        private void PoseExportTimer_Tick(object sender, EventArgs e)
        {
            ExportCurrentPoseSnapshot();
        }

        private void ExportCurrentPoseSnapshot()
        {
            try
            {
                string[] lines;
                if (xARM.IsCreated())
                {
                    float[] joints = xARM.GetCurrentJoint().Take(6).ToArray();
                    float[] cartesianPose = xARM.GetCurrentPosition().ToArray();
                    lines = new[]
                    {
                        "connected,1",
                        "timestamp," + DateTime.Now.ToString("O", CultureInfo.InvariantCulture),
                        "ip," + textBoxIPAdress.Text.Trim(),
                        "joints," + string.Join(",", joints.Select(value => value.ToString(CultureInfo.InvariantCulture))),
                        "cartesian," + string.Join(",", cartesianPose.Select(value => value.ToString(CultureInfo.InvariantCulture)))
                    };
                }
                else
                {
                    lines = new[]
                    {
                        "connected,0",
                        "timestamp," + DateTime.Now.ToString("O", CultureInfo.InvariantCulture),
                        "ip," + textBoxIPAdress.Text.Trim(),
                        "joints,0,0,0,0,0,0",
                        "cartesian,0,0,0,0,0,0"
                    };
                }

                Directory.CreateDirectory(Path.GetDirectoryName(sharedPoseFilePath));
                File.WriteAllLines(sharedPoseFilePath, lines);
            }
            catch
            {
                // Keep the UI responsive even if the bridge file cannot be written temporarily.
            }
        }

        private static string ResolveSharedPoseFilePath()
        {
            DirectoryInfo current = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            while (current != null)
            {
                string candidateFolder = Path.Combine(current.FullName, "conception_mechatronique");
                if (Directory.Exists(candidateFolder))
                {
                    return Path.Combine(candidateFolder, "robot_pose_xarmform.csv");
                }

                current = current.Parent;
            }

            return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "robot_pose_xarmform.csv");
        }
    }

    internal sealed class ForceSample
    {
        public DateTime Timestamp { get; set; }

        public float Force { get; set; }

        public string Unit { get; set; }

        public float DeltaZ { get; set; }

        public float X { get; set; }

        public float Y { get; set; }

        public float Z { get; set; }

        public float Roll { get; set; }

        public float Pitch { get; set; }

        public float Yaw { get; set; }

        public string ToCsvLine()
        {
            return string.Join(
                ",",
                Timestamp.ToString("O", CultureInfo.InvariantCulture),
                Force.ToString(CultureInfo.InvariantCulture),
                Unit ?? string.Empty,
                DeltaZ.ToString(CultureInfo.InvariantCulture),
                X.ToString(CultureInfo.InvariantCulture),
                Y.ToString(CultureInfo.InvariantCulture),
                Z.ToString(CultureInfo.InvariantCulture),
                Roll.ToString(CultureInfo.InvariantCulture),
                Pitch.ToString(CultureInfo.InvariantCulture),
                Yaw.ToString(CultureInfo.InvariantCulture));
        }
    }
}
