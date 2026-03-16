using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace xARMForm
{

    public partial class Form1 : Form
    {
        // Robot arm
        readonly Robot xARM;

        public Form1()
        {
            InitializeComponent();
            xARM = new Robot();
        }

        private void ButtonCreateARM_Click(object sender, EventArgs e)
        {
            string IP = textBoxIPAdress.Text;
            xARM.Create(IP);
            if (xARM.IsCreated())
            {
                // Update GUI
                buttonMotionARM.Enabled = true;

                string version;
                version = xARM.GetVersion();
            }
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
                    buttonResetARM.Enabled = false;
            }
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
        }

        private void ButtonGetJoint_Click(object sender, EventArgs e)
        {
            float[] joint = new float[7];
            int i;
            textBoxJoint.Text = "";
            joint = xARM.GetCurrentJoint();
            for (i = 0; i < 6; i++)
                textBoxJoint.Text += joint[i].ToString("F") + " | ";
            textBoxJoint.Update();
        }

        private void ButtonGetPosition_Click(object sender, EventArgs e)
        {
            float[] pose = new float[6];
            int i;
            textBoxPosition.Text = "";
            pose = xARM.GetCurrentPosition();
            for (i = 0; i < 6; i++)
                textBoxPosition.Text += pose[i].ToString("F") + " | ";
            textBoxPosition.Update();
        }

        private void ButtonGetTCP_Click(object sender, EventArgs e)
        {
            float[] frame = new float[6];
            int i;
            textBoxTCP.Text = "";
            frame = xARM.GetTCP();
            for (i = 0; i < 6; i++)
                textBoxTCP.Text += frame[i].ToString("F") + " | ";
            textBoxTCP.Update();
        }

        private void ButtonGetBase_Click(object sender, EventArgs e)
        {
            float[] frame = new float[6];
            int i;
            textBoxBase.Text = "";
            frame = xARM.GetBase();
            for (i = 0; i < 6; i++)
                textBoxBase.Text += frame[i].ToString("F") + " | ";
            textBoxBase.Update();
        }

        private void ButtonMoveBase_Click(object sender, EventArgs e)
        {
            float[] pose1 = { 300, 0, 200, 180, 0, 0 };
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveBase(pose1, true);
                // Update GUI
                ButtonGetJoint_Click(sender, e);
                ButtonGetPosition_Click(sender, e);
            }
        }

        private void ButtonMoveTCP_Click(object sender, EventArgs e)
        {
            float[] pose2 = { 0, 0, 20, 0, 0, 0 };
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveTool(pose2, true);
                // Update GUI
                ButtonGetJoint_Click(sender, e);
                ButtonGetPosition_Click(sender, e);
            }
        }

        private void ButtonMoveAngle_Click(object sender, EventArgs e)
        {
            float[] angles = new float[7];
            angles = xARM.GetCurrentJoint();
            angles[0] += 10.0F;
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveJointValues(angles);
                // Update GUI
                ButtonGetJoint_Click(sender, e);
                ButtonGetPosition_Click(sender, e);
            }
        }

        private void ButtonMoveHome_Click(object sender, EventArgs e)
        {
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveHome(0, 0, 0, true);
                // Update GUI
                ButtonGetJoint_Click(sender, e);
                ButtonGetPosition_Click(sender, e);
            }
        }

        private void ButtonGetCollisionSensitivity_Click(object sender, EventArgs e)
        {
            int sens;
            if(xARM.IsCreated())
            {
                sens = xARM.GetCollisionSensitivity();
                textBoxCollitionSensitivity.Text = sens.ToString();
                textBoxCollitionSensitivity.Update();
                comboBoxSetCollisionSensitivity.SelectedIndex = sens;
            }
        }

        private void ButtonSetCollisionSensitivity_Click(object sender, EventArgs e)
        {
            int sens;
            int ret = -1;
            if (xARM.IsCreated())
            {
                sens = comboBoxSetCollisionSensitivity.SelectedIndex;
                textBoxCollitionSensitivity.Text = sens.ToString();
                textBoxCollitionSensitivity.Update();
                ret = xARM.SetCollisionSensitivity(sens);
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
            if (xARM.IsCreated())
            {
                xARM.EnableMotion(false);
            }
        }

        private void timerCMD_Tick(object sender, EventArgs e)
        {
            float[] pose2 = { 0, 0, 0.2F, 0, 0, 0 };
            if (xARM.IsCreated() && xARM.IsEnableMotion())
            {
                xARM.MoveTool(pose2, true);
                // Update GUI
                ButtonGetJoint_Click(sender, e);
                ButtonGetPosition_Click(sender, e);
            }
        }

        private void ButtonTimer_Click(object sender, EventArgs e)
        {
            if (buttonTimer.Text == "Start Timer")
            {
                timerCMD.Start();
                buttonTimer.Text = "Stop Timer";
            }
            else
            {
                timerCMD.Stop();
                buttonTimer.Text = "Start Timer";
            }
        }
    }
}
