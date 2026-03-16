using System;
using System.Management;    
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.IO;
using System.IO.Ports;

namespace RS232_PC
{
    public partial class MainForm : Form
    {
        private string portnumber = "COM1";
        private string rs232 = "";
        private string messagetotarget = "";

        public string PortNumber { set { portnumber = value; } get { return portnumber; } }
        public string RS232 { set { rs232 = value; } get { return rs232; } }
        public string MessageToTarget { set { messagetotarget = value; } get { return messagetotarget; } }
        public System.IO.Ports.SerialPort RS232Port { set { } get { return this.SerialPort; } }
        
        public MainForm()
        {
            InitializeComponent();
            textBoxSerial.Text = PortNumber;
        }

        // Run the program
        private void btStart_Click(object sender, EventArgs e)
        {
            // TODO : Add your work here
            MessageBox.Show("To Do");
        }

        // Select file to save in
        private void btSelect_Click(object sender, EventArgs e)
        {
            // TODO : Add your work here
            MessageBox.Show("To Do");
        }
        
        // Save data to file
        private void btSave_Click(object sender, EventArgs e)
        {
            // TODO : Add your work here
            MessageBox.Show("To Do");
        }

        // Open RS232 port
        private void btOpen_Click(object sender, EventArgs e)
        {
            if (RS232Port.IsOpen)
            {
                MessageBox.Show("Serial Port already opened");
            }
            else
            {
                RS232Port.Open();
                btOpen.Enabled = false;
                btClose.Enabled = true;
            }
        }

        // Close RS232 port
        private void btClose_Click(object sender, EventArgs e)
        {
            if (RS232Port.IsOpen)
            {
                RS232Port.Close();
                btOpen.Enabled = true;
                btClose.Enabled = false;
                btConfiguration.Enabled = true;
            }
            else
                MessageBox.Show("Serial Port is not opened");
        }

        // Open the RS232Form to setup the serial port parameters
        private void btConfiguration_Click(object sender, EventArgs e)
        {
            // Add here to code for the action
            RS232Form rsform = new RS232Form();
            // Set actual values to rsform
            rsform.PortName = PortNumber;
            rsform.BaudRate = RS232Port.BaudRate.ToString();
            rsform.Parity = RS232Port.Parity.ToString();
            rsform.StopBits = RS232Port.StopBits.ToString();
            rsform.DataBits = RS232Port.DataBits.ToString();
            rsform.WriteBufferSize = RS232Port.WriteBufferSize.ToString();
            // Update user Interface
            rsform.UpdateGUI();
            // Show rsform as a modal dialog and determine if DialogResult = OK.
            if (rsform.ShowDialog(this) == DialogResult.OK)
            {
                // Read the contents of rsform's TextBox & ComboBox.
                RS232Port.PortName = rsform.PortName;
                RS232Port.BaudRate = int.Parse(rsform.BaudRate);
                // Search the corresponding parity in the Parity Enum define
                switch (rsform.Parity)
                {
                    case "Even":
                        RS232Port.Parity = Parity.Even;
                        break;
                    case "Mark":
                        RS232Port.Parity = Parity.Mark;
                        break;
                    case "None":
                        RS232Port.Parity = Parity.None;
                        break;
                    case "Odd":
                        RS232Port.Parity = Parity.Odd;
                        break;
                    case "Space":
                        RS232Port.Parity = Parity.Space;
                        break;
                    default:
                        break;
                }
                // Search the corresponding stopbits in the StopBits Enum define
                switch (rsform.StopBits)
                {
                    case "None":
                        RS232Port.StopBits = StopBits.None;
                        break;
                    case "One":
                        RS232Port.StopBits = StopBits.One;
                        break;
                    case "OnePointFive":
                        RS232Port.StopBits = StopBits.OnePointFive;
                        break;
                    case "Two":
                        RS232Port.StopBits = StopBits.Two;
                        break;
                    default:
                        break;
                }
                RS232Port.DataBits = int.Parse(rsform.DataBits);
                RS232Port.WriteBufferSize = int.Parse(rsform.WriteBufferSize);
                // bt Open ENABLE
                btOpen.Enabled = true;
                // bt Configuration DISABLE
                btConfiguration.Enabled = false;
            }
            else
            {
                MessageBox.Show("Cancelled");
            }
            rsform.Dispose();
        }

        // Open the About Form
        private void btAbout_Click(object sender, EventArgs e)
        {
            AboutFrom aboutForm = new AboutFrom();
            aboutForm.Show();
        }

        // 
        /// <summary>
        /// Method linked to the DataReceived event
        /// ATTENTION : ReadExisting char  in buffer
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void serialport_DataReceived(object sender, System.IO.Ports.SerialDataReceivedEventArgs e)
        {
            // store in rs232 all existing bytes in the serial port buffer
            rs232 = "";
            rs232 = RS232Port.ReadExisting();
            setReceived(rs232);
        }

        /// <summary>
        /// thread-safe call for Windows Forms Update (asynchronous call).
        /// </summary>
        /// <param name="message"></param>
        delegate void SetMessageCallBack(string message);
        /// <summary>
        /// Update textBoxRS232
        /// </summary>
        /// <param name="message"></param>
        private void setReceived(string message)
        {
            if (textBoxRS232.InvokeRequired) ///InvokeRequired required compares the thread ID of the calling thread to the thread ID of the creating thread. If these threads are different, it returns true.
            {
                SetMessageCallBack d = new SetMessageCallBack(setReceived);
                Invoke(d, new object[] { message });
            }
            else
            {
                textBoxRS232.AppendText(message);                
            }

        }

        /// <summary>
        /// When text changed schroll to the end
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void textBoxRS232_TextChanged(object sender, EventArgs e)
        {
            textBoxRS232.Refresh();
        }

        /// <summary>
        /// When Message to System has changed
        /// Update MessageToTarget string
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void textBoxToSystem_TextChanged(object sender, EventArgs e)
        {
            MessageToTarget = textBoxToSystem.Text;
        }

        /// <summary>
        /// Reset Text in the textBoxRS232 control
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void btReset_Click(object sender, EventArgs e)
        {
            textBoxRS232.Text = "";
            textBoxRS232.Refresh();
        }

        /// <summary>
        /// Write on serial port the text of the textBoxToSystem
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void btSend_Click(object sender, EventArgs e)
        {
            string Message = MessageToTarget;
            if (RS232Port.IsOpen)
            {
                RS232Port.WriteLine(Message);
            }
            else 
            {
                MessageBox.Show("Serial Port not opened");
            }
        }

        /// <summary>
        /// Check all serial ports available in the machine
        /// Add then to listBox in GUI
        /// NEED : add Reference = System.Management
        /// NEED : using System.Management;
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void btListPort_Click(object sender, EventArgs e)
        {
            //show list of valid com ports
            listBoxSerialPort.Items.Clear();
            listBoxSerialDevice.Items.Clear();
            // Get all port names
            string[] portnames = SerialPort.GetPortNames();
            // Search more info on device
            using (var searcher = new ManagementObjectSearcher("SELECT * FROM WIN32_SerialPort"))
            {
                var ports = searcher.Get().Cast<ManagementBaseObject>().ToList();
                var tListNames = (from n in portnames
                             join p in ports on n equals p["DeviceID"].ToString()
                             select p["Caption"]).ToList();
                var tListDevice = (from n in portnames
                             join p in ports on n equals p["DeviceID"].ToString()
                             select n).ToList();
                if (tListDevice.Count != 0)
                {
                    foreach (string s in tListDevice)
                    {
                        listBoxSerialPort.Items.Add(s);
                    }
                    foreach (string s in tListNames)
                    {
                        listBoxSerialDevice.Items.Add(s);
                    }
                    MessageBox.Show("Select by double clic");
                }
                else
                    MessageBox.Show("No Serial Port on the PC");
            }
        }

        /// <summary>
        /// When Serial Port is selected then select Device Name
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void listBoxSerialPort_SelectedIndexChanged(object sender, EventArgs e)
        {
            listBoxSerialDevice.SelectedIndex = listBoxSerialPort.SelectedIndex;
        }

        /// <summary>
        /// When Device Name is selected then select Serial Port
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void listBoxSerialDevice_SelectedIndexChanged(object sender, EventArgs e)
        {
            listBoxSerialPort.SelectedIndex = listBoxSerialDevice.SelectedIndex;
        }
        
        /// <summary>
        /// When double click on list item then update serial port name
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void listBoxSerialPort_DoubleClick(object sender, EventArgs e)
        {
            string text = listBoxSerialPort.GetItemText(listBoxSerialPort.SelectedItem);
            textBoxSerial.Text = text;
            PortNumber = textBoxSerial.Text;
            if (RS232Port.IsOpen)
                MessageBox.Show("Serial port is opened must be closed");
            else
                RS232Port.PortName = PortNumber;

        }

        /// <summary>
        /// When double click on list item then update serial port name
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void listBoxSerialDevice_DoubleClick(object sender, EventArgs e)
        {
            listBoxSerialPort.SelectedItem = listBoxSerialDevice.SelectedIndex;
            string text = listBoxSerialPort.GetItemText(listBoxSerialPort.SelectedItem);
            textBoxSerial.Text = text;
            PortNumber = textBoxSerial.Text;
            if (RS232Port.IsOpen)
                MessageBox.Show("Serial port is opened must close");
            else
                RS232Port.PortName = PortNumber;
        }

        /// <summary>
        /// When new port name has been changed then update serial port name
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void textBoxSerial_TextChanged(object sender, EventArgs e)
        {
            PortNumber = textBoxSerial.Text;
            if (RS232Port.IsOpen)
                MessageBox.Show("Serial port is opened must close");
            else
                RS232Port.PortName = PortNumber;
        }
    }
}
