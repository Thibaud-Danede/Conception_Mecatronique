namespace RS232_PC
{
    partial class MainForm
    {
        /// <summary>
        /// Variable nécessaire au concepteur.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Nettoyage des ressources utilisées.
        /// </summary>
        /// <param name="disposing">true si les ressources managées doivent être supprimées ; sinon, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Code généré par le Concepteur Windows Form

        /// <summary>
        /// Méthode requise pour la prise en charge du concepteur - ne modifiez pas
        /// le contenu de cette méthode avec l'éditeur de code.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            this.textBoxRS232 = new System.Windows.Forms.TextBox();
            this.groupBoxSYSTEM = new System.Windows.Forms.GroupBox();
            this.btReset = new System.Windows.Forms.Button();
            this.groupBoxSERIAL = new System.Windows.Forms.GroupBox();
            this.listBoxSerialDevice = new System.Windows.Forms.ListBox();
            this.listBoxSerialPort = new System.Windows.Forms.ListBox();
            this.btListPort = new System.Windows.Forms.Button();
            this.btClose = new System.Windows.Forms.Button();
            this.btOpen = new System.Windows.Forms.Button();
            this.textBoxSerial = new System.Windows.Forms.TextBox();
            this.btConfiguration = new System.Windows.Forms.Button();
            this.groupBoxRUN = new System.Windows.Forms.GroupBox();
            this.btStart = new System.Windows.Forms.Button();
            this.btSave = new System.Windows.Forms.Button();
            this.groupBoxFILE = new System.Windows.Forms.GroupBox();
            this.btSelect = new System.Windows.Forms.Button();
            this.btAbout = new System.Windows.Forms.Button();
            this.SerialPort = new System.IO.Ports.SerialPort(this.components);
            this.groupBoxToSystem = new System.Windows.Forms.GroupBox();
            this.btSend = new System.Windows.Forms.Button();
            this.textBoxToSystem = new System.Windows.Forms.TextBox();
            this.groupBoxSYSTEM.SuspendLayout();
            this.groupBoxSERIAL.SuspendLayout();
            this.groupBoxRUN.SuspendLayout();
            this.groupBoxFILE.SuspendLayout();
            this.groupBoxToSystem.SuspendLayout();
            this.SuspendLayout();
            // 
            // textBoxRS232
            // 
            this.textBoxRS232.Location = new System.Drawing.Point(6, 66);
            this.textBoxRS232.Multiline = true;
            this.textBoxRS232.Name = "textBoxRS232";
            this.textBoxRS232.ReadOnly = true;
            this.textBoxRS232.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.textBoxRS232.Size = new System.Drawing.Size(459, 138);
            this.textBoxRS232.TabIndex = 0;
            this.textBoxRS232.TextChanged += new System.EventHandler(this.textBoxRS232_TextChanged);
            // 
            // groupBoxSYSTEM
            // 
            this.groupBoxSYSTEM.Controls.Add(this.btReset);
            this.groupBoxSYSTEM.Controls.Add(this.textBoxRS232);
            this.groupBoxSYSTEM.Location = new System.Drawing.Point(11, 107);
            this.groupBoxSYSTEM.Name = "groupBoxSYSTEM";
            this.groupBoxSYSTEM.Size = new System.Drawing.Size(474, 211);
            this.groupBoxSYSTEM.TabIndex = 1;
            this.groupBoxSYSTEM.TabStop = false;
            this.groupBoxSYSTEM.Text = "Message from System";
            // 
            // btReset
            // 
            this.btReset.Location = new System.Drawing.Point(6, 19);
            this.btReset.Name = "btReset";
            this.btReset.Size = new System.Drawing.Size(85, 23);
            this.btReset.TabIndex = 4;
            this.btReset.Text = "Reset";
            this.btReset.UseVisualStyleBackColor = true;
            this.btReset.Click += new System.EventHandler(this.btReset_Click);
            // 
            // groupBoxSERIAL
            // 
            this.groupBoxSERIAL.Controls.Add(this.listBoxSerialDevice);
            this.groupBoxSERIAL.Controls.Add(this.listBoxSerialPort);
            this.groupBoxSERIAL.Controls.Add(this.btListPort);
            this.groupBoxSERIAL.Controls.Add(this.btClose);
            this.groupBoxSERIAL.Controls.Add(this.btOpen);
            this.groupBoxSERIAL.Controls.Add(this.textBoxSerial);
            this.groupBoxSERIAL.Controls.Add(this.btConfiguration);
            this.groupBoxSERIAL.Location = new System.Drawing.Point(491, 159);
            this.groupBoxSERIAL.Name = "groupBoxSERIAL";
            this.groupBoxSERIAL.Size = new System.Drawing.Size(394, 159);
            this.groupBoxSERIAL.TabIndex = 2;
            this.groupBoxSERIAL.TabStop = false;
            this.groupBoxSERIAL.Text = "RS232";
            // 
            // listBoxSerialDevice
            // 
            this.listBoxSerialDevice.FormattingEnabled = true;
            this.listBoxSerialDevice.Location = new System.Drawing.Point(70, 18);
            this.listBoxSerialDevice.Name = "listBoxSerialDevice";
            this.listBoxSerialDevice.Size = new System.Drawing.Size(223, 134);
            this.listBoxSerialDevice.TabIndex = 9;
            this.listBoxSerialDevice.SelectedIndexChanged += new System.EventHandler(this.listBoxSerialDevice_SelectedIndexChanged);
            this.listBoxSerialDevice.DoubleClick += new System.EventHandler(this.listBoxSerialDevice_DoubleClick);
            // 
            // listBoxSerialPort
            // 
            this.listBoxSerialPort.FormattingEnabled = true;
            this.listBoxSerialPort.Location = new System.Drawing.Point(7, 18);
            this.listBoxSerialPort.Name = "listBoxSerialPort";
            this.listBoxSerialPort.Size = new System.Drawing.Size(57, 134);
            this.listBoxSerialPort.TabIndex = 8;
            this.listBoxSerialPort.SelectedIndexChanged += new System.EventHandler(this.listBoxSerialPort_SelectedIndexChanged);
            this.listBoxSerialPort.DoubleClick += new System.EventHandler(this.listBoxSerialPort_DoubleClick);
            // 
            // btListPort
            // 
            this.btListPort.Location = new System.Drawing.Point(299, 21);
            this.btListPort.Name = "btListPort";
            this.btListPort.Size = new System.Drawing.Size(88, 23);
            this.btListPort.TabIndex = 7;
            this.btListPort.Text = "List Port";
            this.btListPort.UseVisualStyleBackColor = true;
            this.btListPort.Click += new System.EventHandler(this.btListPort_Click);
            // 
            // btClose
            // 
            this.btClose.Enabled = false;
            this.btClose.Location = new System.Drawing.Point(299, 126);
            this.btClose.Name = "btClose";
            this.btClose.Size = new System.Drawing.Size(88, 23);
            this.btClose.TabIndex = 6;
            this.btClose.Text = "Close";
            this.btClose.UseVisualStyleBackColor = true;
            this.btClose.Click += new System.EventHandler(this.btClose_Click);
            // 
            // btOpen
            // 
            this.btOpen.Enabled = false;
            this.btOpen.Location = new System.Drawing.Point(299, 99);
            this.btOpen.Name = "btOpen";
            this.btOpen.Size = new System.Drawing.Size(88, 23);
            this.btOpen.TabIndex = 5;
            this.btOpen.Text = "Open";
            this.btOpen.UseVisualStyleBackColor = true;
            this.btOpen.Click += new System.EventHandler(this.btOpen_Click);
            // 
            // textBoxSerial
            // 
            this.textBoxSerial.Location = new System.Drawing.Point(299, 48);
            this.textBoxSerial.Name = "textBoxSerial";
            this.textBoxSerial.Size = new System.Drawing.Size(88, 20);
            this.textBoxSerial.TabIndex = 1;
            this.textBoxSerial.TextChanged += new System.EventHandler(this.textBoxSerial_TextChanged);
            // 
            // btConfiguration
            // 
            this.btConfiguration.Location = new System.Drawing.Point(299, 72);
            this.btConfiguration.Name = "btConfiguration";
            this.btConfiguration.Size = new System.Drawing.Size(88, 23);
            this.btConfiguration.TabIndex = 0;
            this.btConfiguration.Text = "Configuration";
            this.btConfiguration.UseVisualStyleBackColor = true;
            this.btConfiguration.Click += new System.EventHandler(this.btConfiguration_Click);
            // 
            // groupBoxRUN
            // 
            this.groupBoxRUN.Controls.Add(this.btStart);
            this.groupBoxRUN.Location = new System.Drawing.Point(498, 93);
            this.groupBoxRUN.Name = "groupBoxRUN";
            this.groupBoxRUN.Size = new System.Drawing.Size(198, 50);
            this.groupBoxRUN.TabIndex = 4;
            this.groupBoxRUN.TabStop = false;
            this.groupBoxRUN.Text = "Run";
            // 
            // btStart
            // 
            this.btStart.Location = new System.Drawing.Point(94, 14);
            this.btStart.Name = "btStart";
            this.btStart.Size = new System.Drawing.Size(85, 23);
            this.btStart.TabIndex = 0;
            this.btStart.Text = "Start";
            this.btStart.UseVisualStyleBackColor = true;
            this.btStart.Click += new System.EventHandler(this.btStart_Click);
            // 
            // btSave
            // 
            this.btSave.Location = new System.Drawing.Point(94, 46);
            this.btSave.Name = "btSave";
            this.btSave.Size = new System.Drawing.Size(85, 23);
            this.btSave.TabIndex = 3;
            this.btSave.Text = "Save";
            this.btSave.UseVisualStyleBackColor = true;
            this.btSave.Click += new System.EventHandler(this.btSave_Click);
            // 
            // groupBoxFILE
            // 
            this.groupBoxFILE.Controls.Add(this.btSelect);
            this.groupBoxFILE.Controls.Add(this.btSave);
            this.groupBoxFILE.Location = new System.Drawing.Point(498, 12);
            this.groupBoxFILE.Name = "groupBoxFILE";
            this.groupBoxFILE.Size = new System.Drawing.Size(198, 75);
            this.groupBoxFILE.TabIndex = 5;
            this.groupBoxFILE.TabStop = false;
            this.groupBoxFILE.Text = "File";
            // 
            // btSelect
            // 
            this.btSelect.Location = new System.Drawing.Point(94, 12);
            this.btSelect.Name = "btSelect";
            this.btSelect.Size = new System.Drawing.Size(85, 23);
            this.btSelect.TabIndex = 4;
            this.btSelect.Text = "Select";
            this.btSelect.UseVisualStyleBackColor = true;
            this.btSelect.Click += new System.EventHandler(this.btSelect_Click);
            // 
            // btAbout
            // 
            this.btAbout.Location = new System.Drawing.Point(810, 12);
            this.btAbout.Name = "btAbout";
            this.btAbout.Size = new System.Drawing.Size(75, 23);
            this.btAbout.TabIndex = 6;
            this.btAbout.Text = "About";
            this.btAbout.UseVisualStyleBackColor = true;
            this.btAbout.Click += new System.EventHandler(this.btAbout_Click);
            // 
            // SerialPort
            // 
            this.SerialPort.BaudRate = 115200;
            this.SerialPort.PortName = "COM5";
            this.SerialPort.DataReceived += new System.IO.Ports.SerialDataReceivedEventHandler(this.serialport_DataReceived);
            // 
            // groupBoxToSystem
            // 
            this.groupBoxToSystem.Controls.Add(this.btSend);
            this.groupBoxToSystem.Controls.Add(this.textBoxToSystem);
            this.groupBoxToSystem.Location = new System.Drawing.Point(11, 12);
            this.groupBoxToSystem.Name = "groupBoxToSystem";
            this.groupBoxToSystem.Size = new System.Drawing.Size(474, 89);
            this.groupBoxToSystem.TabIndex = 7;
            this.groupBoxToSystem.TabStop = false;
            this.groupBoxToSystem.Text = "Message to System";
            // 
            // btSend
            // 
            this.btSend.Location = new System.Drawing.Point(6, 46);
            this.btSend.Name = "btSend";
            this.btSend.Size = new System.Drawing.Size(85, 23);
            this.btSend.TabIndex = 1;
            this.btSend.Text = "Send";
            this.btSend.UseVisualStyleBackColor = true;
            this.btSend.Click += new System.EventHandler(this.btSend_Click);
            // 
            // textBoxToSystem
            // 
            this.textBoxToSystem.Location = new System.Drawing.Point(15, 20);
            this.textBoxToSystem.Name = "textBoxToSystem";
            this.textBoxToSystem.Size = new System.Drawing.Size(450, 20);
            this.textBoxToSystem.TabIndex = 0;
            this.textBoxToSystem.TextChanged += new System.EventHandler(this.textBoxToSystem_TextChanged);
            // 
            // MainForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(897, 330);
            this.Controls.Add(this.groupBoxToSystem);
            this.Controls.Add(this.btAbout);
            this.Controls.Add(this.groupBoxFILE);
            this.Controls.Add(this.groupBoxSERIAL);
            this.Controls.Add(this.groupBoxSYSTEM);
            this.Controls.Add(this.groupBoxRUN);
            this.Name = "MainForm";
            this.Text = "Sensor & Interfaces";
            this.groupBoxSYSTEM.ResumeLayout(false);
            this.groupBoxSYSTEM.PerformLayout();
            this.groupBoxSERIAL.ResumeLayout(false);
            this.groupBoxSERIAL.PerformLayout();
            this.groupBoxRUN.ResumeLayout(false);
            this.groupBoxFILE.ResumeLayout(false);
            this.groupBoxToSystem.ResumeLayout(false);
            this.groupBoxToSystem.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.TextBox textBoxRS232;
        private System.Windows.Forms.GroupBox groupBoxSYSTEM;
        private System.Windows.Forms.GroupBox groupBoxSERIAL;
        private System.Windows.Forms.TextBox textBoxSerial;
        private System.Windows.Forms.Button btConfiguration;
        private System.Windows.Forms.GroupBox groupBoxRUN;
        private System.Windows.Forms.Button btSave;
        private System.Windows.Forms.GroupBox groupBoxFILE;
        private System.Windows.Forms.Button btAbout;
        private System.IO.Ports.SerialPort SerialPort;
        private System.Windows.Forms.Button btClose;
        private System.Windows.Forms.Button btOpen;
        private System.Windows.Forms.Button btStart;
        private System.Windows.Forms.Button btReset;
        private System.Windows.Forms.GroupBox groupBoxToSystem;
        private System.Windows.Forms.Button btSend;
        private System.Windows.Forms.TextBox textBoxToSystem;
        private System.Windows.Forms.Button btListPort;
        private System.Windows.Forms.Button btSelect;
        private System.Windows.Forms.ListBox listBoxSerialPort;
        private System.Windows.Forms.ListBox listBoxSerialDevice;
    }
}

