namespace RS232_PC
{
    partial class RS232Form
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.comboBoxBaudRate = new System.Windows.Forms.ComboBox();
            this.comboBoxParity = new System.Windows.Forms.ComboBox();
            this.comboBoxDataBits = new System.Windows.Forms.ComboBox();
            this.comboBoxStopBits = new System.Windows.Forms.ComboBox();
            this.comboBoxSendBuffer = new System.Windows.Forms.ComboBox();
            this.LabelBaudRate = new System.Windows.Forms.Label();
            this.labelParity = new System.Windows.Forms.Label();
            this.labelDataBits = new System.Windows.Forms.Label();
            this.labelStopBits = new System.Windows.Forms.Label();
            this.labelSendBuffer = new System.Windows.Forms.Label();
            this.btOK = new System.Windows.Forms.Button();
            this.SuspendLayout();
            // 
            // comboBoxBaudRate
            // 
            this.comboBoxBaudRate.FormattingEnabled = true;
            this.comboBoxBaudRate.Items.AddRange(new object[] {
            "115200",
            "38400",
            "19200",
            "14400",
            "9600",
            "2400"});
            this.comboBoxBaudRate.Location = new System.Drawing.Point(103, 27);
            this.comboBoxBaudRate.Name = "comboBoxBaudRate";
            this.comboBoxBaudRate.Size = new System.Drawing.Size(179, 21);
            this.comboBoxBaudRate.TabIndex = 0;
            this.comboBoxBaudRate.SelectedIndexChanged += new System.EventHandler(this.comboBoxBaudRate_SelectedIndexChanged);
            // 
            // comboBoxParity
            // 
            this.comboBoxParity.FormattingEnabled = true;
            this.comboBoxParity.Items.AddRange(new object[] {
            "None",
            "Odd",
            "Even",
            "Mark",
            "Space"});
            this.comboBoxParity.Location = new System.Drawing.Point(103, 63);
            this.comboBoxParity.Name = "comboBoxParity";
            this.comboBoxParity.Size = new System.Drawing.Size(179, 21);
            this.comboBoxParity.TabIndex = 1;
            this.comboBoxParity.SelectedIndexChanged += new System.EventHandler(this.comboBoxParity_SelectedIndexChanged);
            // 
            // comboBoxDataBits
            // 
            this.comboBoxDataBits.FormattingEnabled = true;
            this.comboBoxDataBits.Items.AddRange(new object[] {
            "8",
            "7",
            "6"});
            this.comboBoxDataBits.Location = new System.Drawing.Point(103, 101);
            this.comboBoxDataBits.Name = "comboBoxDataBits";
            this.comboBoxDataBits.Size = new System.Drawing.Size(179, 21);
            this.comboBoxDataBits.TabIndex = 2;
            this.comboBoxDataBits.SelectedIndexChanged += new System.EventHandler(this.comboBoxDataBits_SelectedIndexChanged);
            // 
            // comboBoxStopBits
            // 
            this.comboBoxStopBits.FormattingEnabled = true;
            this.comboBoxStopBits.Items.AddRange(new object[] {
            "None",
            "One",
            "Two",
            "OnePointFive"});
            this.comboBoxStopBits.Location = new System.Drawing.Point(103, 138);
            this.comboBoxStopBits.Name = "comboBoxStopBits";
            this.comboBoxStopBits.Size = new System.Drawing.Size(179, 21);
            this.comboBoxStopBits.TabIndex = 3;
            this.comboBoxStopBits.SelectedIndexChanged += new System.EventHandler(this.comboBoxStopBits_SelectedIndexChanged);
            // 
            // comboBoxSendBuffer
            // 
            this.comboBoxSendBuffer.FormattingEnabled = true;
            this.comboBoxSendBuffer.Items.AddRange(new object[] {
            "255",
            "512",
            "1024",
            "2048",
            "4096"});
            this.comboBoxSendBuffer.Location = new System.Drawing.Point(103, 175);
            this.comboBoxSendBuffer.Name = "comboBoxSendBuffer";
            this.comboBoxSendBuffer.Size = new System.Drawing.Size(179, 21);
            this.comboBoxSendBuffer.TabIndex = 4;
            this.comboBoxSendBuffer.SelectedIndexChanged += new System.EventHandler(this.comboBoxSendBuffer_SelectedIndexChanged);
            // 
            // LabelBaudRate
            // 
            this.LabelBaudRate.AutoSize = true;
            this.LabelBaudRate.Location = new System.Drawing.Point(13, 34);
            this.LabelBaudRate.Name = "LabelBaudRate";
            this.LabelBaudRate.Size = new System.Drawing.Size(58, 13);
            this.LabelBaudRate.TabIndex = 6;
            this.LabelBaudRate.Text = "BaudRate:";
            // 
            // labelParity
            // 
            this.labelParity.AutoSize = true;
            this.labelParity.Location = new System.Drawing.Point(12, 66);
            this.labelParity.Name = "labelParity";
            this.labelParity.Size = new System.Drawing.Size(36, 13);
            this.labelParity.TabIndex = 7;
            this.labelParity.Text = "Parity:";
            // 
            // labelDataBits
            // 
            this.labelDataBits.AutoSize = true;
            this.labelDataBits.Location = new System.Drawing.Point(13, 104);
            this.labelDataBits.Name = "labelDataBits";
            this.labelDataBits.Size = new System.Drawing.Size(49, 13);
            this.labelDataBits.TabIndex = 8;
            this.labelDataBits.Text = "Databits:";
            // 
            // labelStopBits
            // 
            this.labelStopBits.AutoSize = true;
            this.labelStopBits.Location = new System.Drawing.Point(13, 141);
            this.labelStopBits.Name = "labelStopBits";
            this.labelStopBits.Size = new System.Drawing.Size(49, 13);
            this.labelStopBits.TabIndex = 9;
            this.labelStopBits.Text = "StopBits:";
            // 
            // labelSendBuffer
            // 
            this.labelSendBuffer.AutoSize = true;
            this.labelSendBuffer.Location = new System.Drawing.Point(13, 178);
            this.labelSendBuffer.Name = "labelSendBuffer";
            this.labelSendBuffer.Size = new System.Drawing.Size(63, 13);
            this.labelSendBuffer.TabIndex = 10;
            this.labelSendBuffer.Text = "SendBuffer:";
            // 
            // btOK
            // 
            this.btOK.Location = new System.Drawing.Point(138, 219);
            this.btOK.Name = "btOK";
            this.btOK.Size = new System.Drawing.Size(75, 23);
            this.btOK.TabIndex = 13;
            this.btOK.Text = "OK";
            this.btOK.UseVisualStyleBackColor = true;
            this.btOK.Click += new System.EventHandler(this.btOK_Click);
            // 
            // RS232Form
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(365, 258);
            this.Controls.Add(this.btOK);
            this.Controls.Add(this.labelSendBuffer);
            this.Controls.Add(this.labelStopBits);
            this.Controls.Add(this.labelDataBits);
            this.Controls.Add(this.labelParity);
            this.Controls.Add(this.LabelBaudRate);
            this.Controls.Add(this.comboBoxSendBuffer);
            this.Controls.Add(this.comboBoxStopBits);
            this.Controls.Add(this.comboBoxDataBits);
            this.Controls.Add(this.comboBoxParity);
            this.Controls.Add(this.comboBoxBaudRate);
            this.Name = "RS232Form";
            this.Text = "Port Configuration";
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.ComboBox comboBoxBaudRate;
        private System.Windows.Forms.ComboBox comboBoxParity;
        private System.Windows.Forms.ComboBox comboBoxDataBits;
        private System.Windows.Forms.ComboBox comboBoxStopBits;
        private System.Windows.Forms.ComboBox comboBoxSendBuffer;
        private System.Windows.Forms.Label LabelBaudRate;
        private System.Windows.Forms.Label labelParity;
        private System.Windows.Forms.Label labelDataBits;
        private System.Windows.Forms.Label labelStopBits;
        private System.Windows.Forms.Label labelSendBuffer;
        private System.Windows.Forms.Button btOK;
    }
}