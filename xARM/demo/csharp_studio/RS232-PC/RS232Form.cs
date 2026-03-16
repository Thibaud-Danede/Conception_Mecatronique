using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace RS232_PC
{
    public partial class RS232Form : Form
    {
        private MainForm mainFrom;
        private string _portname;
        private string _baudrate;
        private string _parity;
        private string _stopbits;
        private string _databits;
        private string _writebuffersize;

        public string PortName { set{_portname = value;} get{ return _portname;}}
        public string BaudRate { set { _baudrate = value; } get { return _baudrate; } }
        public string Parity { set { _parity = value; } get { return _parity; } }
        public string StopBits { set { _stopbits = value; } get { return _stopbits; } }
        public string DataBits { set { _databits = value; } get { return _databits; } }
        public string WriteBufferSize { set { _writebuffersize = value; } get { return _writebuffersize; } }

        public RS232Form()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Update GUI
        /// </summary>
        public void UpdateGUI()
        {
            // Set current values to form
            int index;
            index = comboBoxBaudRate.FindString(BaudRate);
            comboBoxBaudRate.SelectedIndex = index;
            index = comboBoxParity.FindString(Parity);
            comboBoxParity.SelectedIndex = index;
            index = comboBoxStopBits.FindString(StopBits);
            comboBoxStopBits.SelectedIndex = index;
            index = comboBoxDataBits.FindString(DataBits);
            comboBoxDataBits.SelectedIndex = index;
            index = comboBoxSendBuffer.FindString(WriteBufferSize);
            comboBoxSendBuffer.SelectedIndex = index;
        }

        /// <summary>
        /// Action when OK button clicked
        /// Set Dialog result to OK value before quitting
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void btOK_Click(object sender, EventArgs e)
        {
            // Close the Windows form RS232Form
            DialogResult = DialogResult.OK;
            Close();
        }

        /// <summary>
        /// Action when index changed in the comboBox
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void comboBoxBaudRate_SelectedIndexChanged(object sender, EventArgs e)
        {
            BaudRate = comboBoxBaudRate.SelectedItem.ToString();
        }

        /// <summary>
        ///  Action when index changed in the comboBox
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void comboBoxParity_SelectedIndexChanged(object sender, EventArgs e)
        {
            Parity = comboBoxParity.SelectedItem.ToString();
        }

        /// <summary>
        ///  Action when index changed in the comboBox
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void comboBoxDataBits_SelectedIndexChanged(object sender, EventArgs e)
        {
            DataBits = comboBoxDataBits.SelectedItem.ToString();
        }

        /// <summary>
        ///  Action when index changed in the comboBox
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void comboBoxStopBits_SelectedIndexChanged(object sender, EventArgs e)
        {
            StopBits = comboBoxStopBits.SelectedItem.ToString();
        }

        /// <summary>
        ///  Action when index changed in the comboBox
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void comboBoxSendBuffer_SelectedIndexChanged(object sender, EventArgs e)
        {
            WriteBufferSize = comboBoxSendBuffer.SelectedItem.ToString();
        }
    }
}
