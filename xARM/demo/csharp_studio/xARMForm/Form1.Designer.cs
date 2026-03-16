namespace xARMForm
{
    partial class Form1
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
            this.textBoxIPAdress = new System.Windows.Forms.TextBox();
            this.labelIPAdress = new System.Windows.Forms.Label();
            this.buttonCreateARM = new System.Windows.Forms.Button();
            this.buttonGetJoint = new System.Windows.Forms.Button();
            this.textBoxJoint = new System.Windows.Forms.TextBox();
            this.buttonResetARM = new System.Windows.Forms.Button();
            this.textBoxPosition = new System.Windows.Forms.TextBox();
            this.buttonGetPosition = new System.Windows.Forms.Button();
            this.textBoxBase = new System.Windows.Forms.TextBox();
            this.buttonGetBase = new System.Windows.Forms.Button();
            this.textBoxTCP = new System.Windows.Forms.TextBox();
            this.buttonGetTCP = new System.Windows.Forms.Button();
            this.buttonMoveBase = new System.Windows.Forms.Button();
            this.buttonMoveTCP = new System.Windows.Forms.Button();
            this.buttonMoveAngle = new System.Windows.Forms.Button();
            this.buttonMoveHome = new System.Windows.Forms.Button();
            this.buttonMotionARM = new System.Windows.Forms.Button();
            this.buttonGetCollisionSensitivity = new System.Windows.Forms.Button();
            this.textBoxCollitionSensitivity = new System.Windows.Forms.TextBox();
            this.timerCMD = new System.Windows.Forms.Timer(this.components);
            this.buttonTimer = new System.Windows.Forms.Button();
            this.buttonSelfCollision = new System.Windows.Forms.Button();
            this.checkBoxSelfCollision = new System.Windows.Forms.CheckBox();
            this.buttonSetCollisionSensitivity = new System.Windows.Forms.Button();
            this.comboBoxSetCollisionSensitivity = new System.Windows.Forms.ComboBox();
            this.SuspendLayout();
            // 
            // textBoxIPAdress
            // 
            this.textBoxIPAdress.Location = new System.Drawing.Point(94, 42);
            this.textBoxIPAdress.Name = "textBoxIPAdress";
            this.textBoxIPAdress.Size = new System.Drawing.Size(100, 20);
            this.textBoxIPAdress.TabIndex = 0;
            this.textBoxIPAdress.Text = "192.168.1.214";
            // 
            // labelIPAdress
            // 
            this.labelIPAdress.AutoSize = true;
            this.labelIPAdress.Location = new System.Drawing.Point(41, 46);
            this.labelIPAdress.Name = "labelIPAdress";
            this.labelIPAdress.Size = new System.Drawing.Size(52, 13);
            this.labelIPAdress.TabIndex = 1;
            this.labelIPAdress.Text = "IP Adress";
            // 
            // buttonCreateARM
            // 
            this.buttonCreateARM.Location = new System.Drawing.Point(44, 83);
            this.buttonCreateARM.Name = "buttonCreateARM";
            this.buttonCreateARM.Size = new System.Drawing.Size(103, 23);
            this.buttonCreateARM.TabIndex = 2;
            this.buttonCreateARM.Text = "Create xARM";
            this.buttonCreateARM.UseVisualStyleBackColor = true;
            this.buttonCreateARM.Click += new System.EventHandler(this.ButtonCreateARM_Click);
            // 
            // buttonGetJoint
            // 
            this.buttonGetJoint.Enabled = false;
            this.buttonGetJoint.Location = new System.Drawing.Point(282, 46);
            this.buttonGetJoint.Name = "buttonGetJoint";
            this.buttonGetJoint.Size = new System.Drawing.Size(75, 23);
            this.buttonGetJoint.TabIndex = 3;
            this.buttonGetJoint.Text = "Get Joint";
            this.buttonGetJoint.UseVisualStyleBackColor = true;
            this.buttonGetJoint.Click += new System.EventHandler(this.ButtonGetJoint_Click);
            // 
            // textBoxJoint
            // 
            this.textBoxJoint.Location = new System.Drawing.Point(378, 48);
            this.textBoxJoint.Name = "textBoxJoint";
            this.textBoxJoint.ReadOnly = true;
            this.textBoxJoint.Size = new System.Drawing.Size(235, 20);
            this.textBoxJoint.TabIndex = 4;
            // 
            // buttonResetARM
            // 
            this.buttonResetARM.Enabled = false;
            this.buttonResetARM.Location = new System.Drawing.Point(44, 141);
            this.buttonResetARM.Name = "buttonResetARM";
            this.buttonResetARM.Size = new System.Drawing.Size(103, 23);
            this.buttonResetARM.TabIndex = 5;
            this.buttonResetARM.Text = "Reset xARM";
            this.buttonResetARM.UseVisualStyleBackColor = true;
            this.buttonResetARM.Click += new System.EventHandler(this.ButtonResetARM_Click);
            // 
            // textBoxPosition
            // 
            this.textBoxPosition.Location = new System.Drawing.Point(378, 77);
            this.textBoxPosition.Name = "textBoxPosition";
            this.textBoxPosition.ReadOnly = true;
            this.textBoxPosition.Size = new System.Drawing.Size(235, 20);
            this.textBoxPosition.TabIndex = 7;
            // 
            // buttonGetPosition
            // 
            this.buttonGetPosition.Enabled = false;
            this.buttonGetPosition.Location = new System.Drawing.Point(282, 75);
            this.buttonGetPosition.Name = "buttonGetPosition";
            this.buttonGetPosition.Size = new System.Drawing.Size(75, 23);
            this.buttonGetPosition.TabIndex = 6;
            this.buttonGetPosition.Text = "Get Position";
            this.buttonGetPosition.UseVisualStyleBackColor = true;
            this.buttonGetPosition.Click += new System.EventHandler(this.ButtonGetPosition_Click);
            // 
            // textBoxBase
            // 
            this.textBoxBase.Location = new System.Drawing.Point(378, 106);
            this.textBoxBase.Name = "textBoxBase";
            this.textBoxBase.ReadOnly = true;
            this.textBoxBase.Size = new System.Drawing.Size(235, 20);
            this.textBoxBase.TabIndex = 9;
            // 
            // buttonGetBase
            // 
            this.buttonGetBase.Enabled = false;
            this.buttonGetBase.Location = new System.Drawing.Point(282, 104);
            this.buttonGetBase.Name = "buttonGetBase";
            this.buttonGetBase.Size = new System.Drawing.Size(75, 23);
            this.buttonGetBase.TabIndex = 8;
            this.buttonGetBase.Text = "Get Base";
            this.buttonGetBase.UseVisualStyleBackColor = true;
            this.buttonGetBase.Click += new System.EventHandler(this.ButtonGetBase_Click);
            // 
            // textBoxTCP
            // 
            this.textBoxTCP.Location = new System.Drawing.Point(378, 135);
            this.textBoxTCP.Name = "textBoxTCP";
            this.textBoxTCP.ReadOnly = true;
            this.textBoxTCP.Size = new System.Drawing.Size(235, 20);
            this.textBoxTCP.TabIndex = 11;
            // 
            // buttonGetTCP
            // 
            this.buttonGetTCP.Enabled = false;
            this.buttonGetTCP.Location = new System.Drawing.Point(282, 133);
            this.buttonGetTCP.Name = "buttonGetTCP";
            this.buttonGetTCP.Size = new System.Drawing.Size(75, 23);
            this.buttonGetTCP.TabIndex = 10;
            this.buttonGetTCP.Text = "Get TCP";
            this.buttonGetTCP.UseVisualStyleBackColor = true;
            this.buttonGetTCP.Click += new System.EventHandler(this.ButtonGetTCP_Click);
            // 
            // buttonMoveBase
            // 
            this.buttonMoveBase.Enabled = false;
            this.buttonMoveBase.Location = new System.Drawing.Point(282, 201);
            this.buttonMoveBase.Name = "buttonMoveBase";
            this.buttonMoveBase.Size = new System.Drawing.Size(75, 23);
            this.buttonMoveBase.TabIndex = 12;
            this.buttonMoveBase.Text = "Move Base";
            this.buttonMoveBase.UseVisualStyleBackColor = true;
            this.buttonMoveBase.Click += new System.EventHandler(this.ButtonMoveBase_Click);
            // 
            // buttonMoveTCP
            // 
            this.buttonMoveTCP.Enabled = false;
            this.buttonMoveTCP.Location = new System.Drawing.Point(282, 230);
            this.buttonMoveTCP.Name = "buttonMoveTCP";
            this.buttonMoveTCP.Size = new System.Drawing.Size(75, 23);
            this.buttonMoveTCP.TabIndex = 13;
            this.buttonMoveTCP.Text = "Move TCP";
            this.buttonMoveTCP.UseVisualStyleBackColor = true;
            this.buttonMoveTCP.Click += new System.EventHandler(this.ButtonMoveTCP_Click);
            // 
            // buttonMoveAngle
            // 
            this.buttonMoveAngle.Enabled = false;
            this.buttonMoveAngle.Location = new System.Drawing.Point(282, 259);
            this.buttonMoveAngle.Name = "buttonMoveAngle";
            this.buttonMoveAngle.Size = new System.Drawing.Size(75, 23);
            this.buttonMoveAngle.TabIndex = 14;
            this.buttonMoveAngle.Text = "Move Angle";
            this.buttonMoveAngle.UseVisualStyleBackColor = true;
            this.buttonMoveAngle.Click += new System.EventHandler(this.ButtonMoveAngle_Click);
            // 
            // buttonMoveHome
            // 
            this.buttonMoveHome.Enabled = false;
            this.buttonMoveHome.Location = new System.Drawing.Point(282, 172);
            this.buttonMoveHome.Name = "buttonMoveHome";
            this.buttonMoveHome.Size = new System.Drawing.Size(75, 23);
            this.buttonMoveHome.TabIndex = 15;
            this.buttonMoveHome.Text = "Move Home";
            this.buttonMoveHome.UseVisualStyleBackColor = true;
            this.buttonMoveHome.Click += new System.EventHandler(this.ButtonMoveHome_Click);
            // 
            // buttonMotionARM
            // 
            this.buttonMotionARM.Enabled = false;
            this.buttonMotionARM.Location = new System.Drawing.Point(44, 112);
            this.buttonMotionARM.Name = "buttonMotionARM";
            this.buttonMotionARM.Size = new System.Drawing.Size(103, 23);
            this.buttonMotionARM.TabIndex = 16;
            this.buttonMotionARM.Text = "Motion xARM";
            this.buttonMotionARM.UseVisualStyleBackColor = true;
            this.buttonMotionARM.Click += new System.EventHandler(this.ButtonMotionARM_Click);
            // 
            // buttonGetCollisionSensitivity
            // 
            this.buttonGetCollisionSensitivity.Enabled = false;
            this.buttonGetCollisionSensitivity.Location = new System.Drawing.Point(44, 172);
            this.buttonGetCollisionSensitivity.Name = "buttonGetCollisionSensitivity";
            this.buttonGetCollisionSensitivity.Size = new System.Drawing.Size(128, 23);
            this.buttonGetCollisionSensitivity.TabIndex = 17;
            this.buttonGetCollisionSensitivity.Text = "Get Collision Sensitivity";
            this.buttonGetCollisionSensitivity.UseVisualStyleBackColor = true;
            this.buttonGetCollisionSensitivity.Click += new System.EventHandler(this.ButtonGetCollisionSensitivity_Click);
            // 
            // textBoxCollitionSensitivity
            // 
            this.textBoxCollitionSensitivity.Location = new System.Drawing.Point(178, 174);
            this.textBoxCollitionSensitivity.Name = "textBoxCollitionSensitivity";
            this.textBoxCollitionSensitivity.ReadOnly = true;
            this.textBoxCollitionSensitivity.Size = new System.Drawing.Size(68, 20);
            this.textBoxCollitionSensitivity.TabIndex = 18;
            // 
            // timerCMD
            // 
            this.timerCMD.Tick += new System.EventHandler(this.timerCMD_Tick);
            // 
            // buttonTimer
            // 
            this.buttonTimer.Location = new System.Drawing.Point(630, 48);
            this.buttonTimer.Name = "buttonTimer";
            this.buttonTimer.Size = new System.Drawing.Size(75, 23);
            this.buttonTimer.TabIndex = 19;
            this.buttonTimer.Text = "Start Timer";
            this.buttonTimer.UseVisualStyleBackColor = true;
            this.buttonTimer.Click += new System.EventHandler(this.ButtonTimer_Click);
            // 
            // buttonSelfCollision
            // 
            this.buttonSelfCollision.Enabled = false;
            this.buttonSelfCollision.Location = new System.Drawing.Point(44, 230);
            this.buttonSelfCollision.Name = "buttonSelfCollision";
            this.buttonSelfCollision.Size = new System.Drawing.Size(128, 23);
            this.buttonSelfCollision.TabIndex = 20;
            this.buttonSelfCollision.Text = "Self Collision Detection";
            this.buttonSelfCollision.UseVisualStyleBackColor = true;
            this.buttonSelfCollision.Click += new System.EventHandler(this.ButtonSelfCollision_Click);
            // 
            // checkBoxSelfCollision
            // 
            this.checkBoxSelfCollision.AutoSize = true;
            this.checkBoxSelfCollision.Location = new System.Drawing.Point(178, 234);
            this.checkBoxSelfCollision.Name = "checkBoxSelfCollision";
            this.checkBoxSelfCollision.Size = new System.Drawing.Size(85, 17);
            this.checkBoxSelfCollision.TabIndex = 21;
            this.checkBoxSelfCollision.Text = "Self Collision";
            this.checkBoxSelfCollision.UseVisualStyleBackColor = true;
            // 
            // buttonSetCollisionSensitivity
            // 
            this.buttonSetCollisionSensitivity.Enabled = false;
            this.buttonSetCollisionSensitivity.Location = new System.Drawing.Point(44, 201);
            this.buttonSetCollisionSensitivity.Name = "buttonSetCollisionSensitivity";
            this.buttonSetCollisionSensitivity.Size = new System.Drawing.Size(128, 23);
            this.buttonSetCollisionSensitivity.TabIndex = 22;
            this.buttonSetCollisionSensitivity.Text = "Set Collision Sensitivity";
            this.buttonSetCollisionSensitivity.UseVisualStyleBackColor = true;
            this.buttonSetCollisionSensitivity.Click += new System.EventHandler(this.ButtonSetCollisionSensitivity_Click);
            // 
            // comboBoxSetCollisionSensitivity
            // 
            this.comboBoxSetCollisionSensitivity.FormattingEnabled = true;
            this.comboBoxSetCollisionSensitivity.Items.AddRange(new object[] {
            "0",
            "1",
            "2",
            "3",
            "4",
            "5"});
            this.comboBoxSetCollisionSensitivity.Location = new System.Drawing.Point(178, 203);
            this.comboBoxSetCollisionSensitivity.Name = "comboBoxSetCollisionSensitivity";
            this.comboBoxSetCollisionSensitivity.Size = new System.Drawing.Size(68, 21);
            this.comboBoxSetCollisionSensitivity.TabIndex = 23;
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(736, 450);
            this.Controls.Add(this.comboBoxSetCollisionSensitivity);
            this.Controls.Add(this.buttonSetCollisionSensitivity);
            this.Controls.Add(this.checkBoxSelfCollision);
            this.Controls.Add(this.buttonSelfCollision);
            this.Controls.Add(this.buttonTimer);
            this.Controls.Add(this.textBoxCollitionSensitivity);
            this.Controls.Add(this.buttonGetCollisionSensitivity);
            this.Controls.Add(this.buttonMotionARM);
            this.Controls.Add(this.buttonMoveHome);
            this.Controls.Add(this.buttonMoveAngle);
            this.Controls.Add(this.buttonMoveTCP);
            this.Controls.Add(this.buttonMoveBase);
            this.Controls.Add(this.textBoxTCP);
            this.Controls.Add(this.buttonGetTCP);
            this.Controls.Add(this.textBoxBase);
            this.Controls.Add(this.buttonGetBase);
            this.Controls.Add(this.textBoxPosition);
            this.Controls.Add(this.buttonGetPosition);
            this.Controls.Add(this.buttonResetARM);
            this.Controls.Add(this.textBoxJoint);
            this.Controls.Add(this.buttonGetJoint);
            this.Controls.Add(this.buttonCreateARM);
            this.Controls.Add(this.labelIPAdress);
            this.Controls.Add(this.textBoxIPAdress);
            this.Name = "Form1";
            this.Text = "xARM Application";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.Form1_FormClosing);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.TextBox textBoxIPAdress;
        private System.Windows.Forms.Label labelIPAdress;
        private System.Windows.Forms.Button buttonCreateARM;
        private System.Windows.Forms.Button buttonGetJoint;
        private System.Windows.Forms.TextBox textBoxJoint;
        private System.Windows.Forms.Button buttonResetARM;
        private System.Windows.Forms.TextBox textBoxPosition;
        private System.Windows.Forms.Button buttonGetPosition;
        private System.Windows.Forms.TextBox textBoxBase;
        private System.Windows.Forms.Button buttonGetBase;
        private System.Windows.Forms.TextBox textBoxTCP;
        private System.Windows.Forms.Button buttonGetTCP;
        private System.Windows.Forms.Button buttonMoveBase;
        private System.Windows.Forms.Button buttonMoveTCP;
        private System.Windows.Forms.Button buttonMoveAngle;
        private System.Windows.Forms.Button buttonMoveHome;
        private System.Windows.Forms.Button buttonMotionARM;
        private System.Windows.Forms.Button buttonGetCollisionSensitivity;
        private System.Windows.Forms.TextBox textBoxCollitionSensitivity;
        private System.Windows.Forms.Timer timerCMD;
        private System.Windows.Forms.Button buttonTimer;
        private System.Windows.Forms.Button buttonSelfCollision;
        private System.Windows.Forms.CheckBox checkBoxSelfCollision;
        private System.Windows.Forms.Button buttonSetCollisionSensitivity;
        private System.Windows.Forms.ComboBox comboBoxSetCollisionSensitivity;
    }
}

