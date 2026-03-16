using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TaskbarClock;

namespace xARMForm
{
    internal class Robot
    {
        public const float NO_TIMEOUT = -1;

        protected
            int arm;
            bool xArmCreatedFlag;
            bool EnableMotionFlag;
            bool SelfCollisionFlag;
            bool WaitFlag;
            bool SafetyFlag;
            float TimeOut;
            int CollisionSensitivity;
            int TeachSensitivity;

        public
            float JointSpeed;
            float JointAcceleration;
            float[] CurrentPosition = new float[6];
            float[] OriginePosition = new float[6];
            float[] HomeJoint = new float[7];
            float[] TCP = new float[6];
            float[] BASE = new float[6];
            int[] TCPBoundary = new int[6];
            float[] CurrentJoint = new float[7];
            float[] MinJoint = new float[7];
            float[] MaxJoint = new float[7];

        public Robot()
        {
            arm = -1;
            xArmCreatedFlag = false;
            EnableMotionFlag = false;
            SelfCollisionFlag = false;
            WaitFlag = true;
            SafetyFlag = false;
            TimeOut = -1;
            // Init Motion
            JointSpeed = 9.0F;
            JointAcceleration = 1000.0F;
            // Init Arrays
            int i;
            for (i = 0; i < 6; i++)
            {
                CurrentPosition[i] = 0.0F;
                OriginePosition[i] = 0.0F;
                TCP[i] = 0.0F;
                BASE[i] = 0.0F;
                TCPBoundary[i] = 0;
            }
            for (i = 0; i < 7; i++)
            {
                HomeJoint[i] = 0.0F;
                CurrentJoint[i] = 0.0F;
            }
            MinJoint[0] = -360.0F;
            MaxJoint[0] = +360.0F;
            MinJoint[1] = -118.0F;
            MaxJoint[1] = +120.0F;
            MinJoint[2] = -225.0F;
            MaxJoint[2] = +11.0F;
            MinJoint[3] = -360.0F;
            MaxJoint[3] = +360.0F;
            MinJoint[4] = -97.0F;
            MaxJoint[4] = +180.0F;
            MinJoint[5] = -360.0F;
            MaxJoint[5] = +360.0F;
            MinJoint[6] = 0.0F;
            MaxJoint[6] = 0.0F;
        }

        public bool Create(string IP)
        {
            int ret;
            if (arm == -1)
            {
                arm = XArmAPI.create_instance(IP, false);
                if (arm != -1)
                {
                    ret = XArmAPI.switch_xarm(arm);
                    xArmCreatedFlag = true;
                    if (ret == 0)
                    {
                        // Prepare to start
                        ret = XArmAPI.clean_warn();
                        ret = XArmAPI.clean_error();
                        // Retreive Data
                        ret = XArmAPI.get_world_offset(BASE);
                        ret = XArmAPI.get_tcp_offset(TCP);
                        ret = XArmAPI.get_position(CurrentPosition);
                        ret = XArmAPI.get_servo_angle(CurrentJoint);
                        // Set Data
                        CollisionSensitivity = 3;
                        XArmAPI.set_collision_sensitivity(CollisionSensitivity);
                        TeachSensitivity = 3;
                        XArmAPI.set_teach_sensitivity(TeachSensitivity);
                        SelfCollisionFlag = false;
                        XArmAPI.set_self_collision_detection(SelfCollisionFlag);
                        // Prepare to move
                        //EnableMotionFlag = true;
                        //ret = XArmAPI.motion_enable(EnableMotionFlag);
                        //ret = XArmAPI.set_mode(0);
                        //ret = XArmAPI.set_state(0);
                    }
                }
                else
                    xArmCreatedFlag = false;
            }
            return xArmCreatedFlag;
        }

        public string GetVersion()
        {
            string s = "Test";
            byte[] version = new byte[10];
            XArmAPI.get_version(version) ;
            s = version.ToString();
            return s;
        }

        public bool IsCreated()
        {
            return xArmCreatedFlag;
        }

        public bool IsEnableMotion()
        {
            return EnableMotionFlag;
        }
        public void Reset()
        {
            if(xArmCreatedFlag)
                XArmAPI.reset(true);
        }

        //
        public void ClearErrorCode()
        {
            int ret;
            if (xArmCreatedFlag)
                ret = XArmAPI.clean_error();
        }

        public void ClearWarnCode()
        {
            int ret;
            if (xArmCreatedFlag)
                ret = XArmAPI.clean_warn();
        }

        public int SetSelfCollision(bool flag)
        {
            int ret = -1;
            if (xArmCreatedFlag)
            {
                ret = XArmAPI.set_self_collision_detection(flag);
                SelfCollisionFlag = flag;
            }
            return ret;
        }
        public bool GetSelfCollision()
        {
            return SelfCollisionFlag;
        }

        public int SetCollisionSensitivity(int sens)
        {
            int s;
            switch (sens)
            {
                case 0: 
                case 1: 
                case 2: 
                case 3: 
                case 4: 
                case 5: s = sens; break;
                default: s = 3; break;
            }
            CollisionSensitivity = s;
            XArmAPI.set_collision_sensitivity(s);
            return s;
        }

        public int GetCollisionSensitivity()
        {
            int s;
            s = CollisionSensitivity;
            return s;
        }

        public int SetTeachSensitivity(int sens)
        {
            int s;
            switch (sens)
            {
                case 0:
                case 1:
                case 2:
                case 3:
                case 4:
                case 5: s = sens; break;
                default: s = 3; break;
            }
            TeachSensitivity = s;
            XArmAPI.set_teach_sensitivity(s);
            return s;
        }

        public int GetTeachSensitivity()
        {
            int s;
            s = TeachSensitivity;
            return s;
        }

        public void SetSafetyBoundary(int[] boundary)
        {
            int i;
            if(xArmCreatedFlag)
            {
                XArmAPI.set_reduced_tcp_boundary(boundary);
                for (i = 0; i < 6; i++)
                    TCPBoundary[i] = boundary[i];
                SafetyFlag = true;
            }
        }

        public int[] GetSafetyBoundary()
        {
            int i;
            int[] boundary = new int[6];
            if (xArmCreatedFlag && SafetyFlag)
            {
                for (i = 0; i < 6; i++)
                     boundary[i] = TCPBoundary[i];
                SafetyFlag = true;
            }
            return boundary;
        }

        public int ActivateSafetyBoundary(bool flag)
        {
            int ret = -1;
            if (xArmCreatedFlag && SafetyFlag)
            {
                ret = XArmAPI.set_fense_mode(flag);
            }
            return ret;
        }

        public int EnableMotion(bool flag)
        {
            int ret = -1;
            if(xArmCreatedFlag)
                ret = XArmAPI.motion_enable(flag);
            EnableMotionFlag = flag;
            return ret;
        }

        //Mode 0: Position control mode.
        //Mode 1 : Servoj mode.
        //Mode 2: Joint teaching mode.
        //Mode 4 : Cartesian teaching mode, (not yet available).
        public void SetMode(int mode)
        {
            if(xArmCreatedFlag)
                XArmAPI.set_mode(mode); 
        }

        public int GetMode()
        {
            int mode = -1;
            if (xArmCreatedFlag)
                mode = XArmAPI.get_mode();
            return mode;
        }

        //State 0: Start motion.
        //State 3: Paused state.
        //State 4 : Stop state.
        public int SetState(int state)
        {
            int ret = -1;
            if(xArmCreatedFlag)
                ret = XArmAPI.set_state(state);
            return ret;
        }

        public int GetState()
        {
            int ret = -1;
            int state = -1;
            if (xArmCreatedFlag)
                ret = XArmAPI.get_state(ref state);
            return ret;
        }

        // world_offset Get Set
        public float[] GetBase()
        {
            XArmAPI.get_world_offset(BASE);
            int i;
            float[] Frame = {0,0,0,0,0,0};
            for (i = 0; i < 6; i++)
                Frame[i] = BASE[i];
            return Frame;
        }

        public void SetBase(float[] Frame)
        {
            int i;
            for (i = 0; i < 6; i++)
                BASE[i] = Frame[i]; 
            XArmAPI.set_world_offset(BASE);
        }

        // tcp_offset Get Set
        public float[] GetTCP()
        {
            XArmAPI.get_tcp_offset(TCP);
            int i;
            float[] Frame = { 0, 0, 0, 0, 0, 0 };
            for (i = 0; i < 6; i++)
                Frame[i] = TCP[i];
            return Frame;
        }

        public void SetTCP(float[] Frame)
        {
            int i;
            for (i = 0; i < 6; i++)
                TCP[i] = Frame[i];
            XArmAPI.set_tcp_offset(TCP);
        }

        public float[] GetCurrentJoint()
        {
            float[] angles = new float[7];
            XArmAPI.get_servo_angle(angles);
            int i;
            for (i = 0; i < 7; i++)
                CurrentJoint[i] = angles[i];
            return CurrentJoint;
        }

        public float[] GetCurrentPosition()
        {
            float[] pose = new float[6];
            XArmAPI.get_position(pose);
            int i;
            for (i = 0; i < 6; i++)
                CurrentPosition[i] = pose[i];
            return CurrentPosition;
        }

        // set_servo_angle(float[] angles, float speed = 0, float acc = 0, float mvtime = 0, bool wait = false, float timeout = NO_TIMEOUT, float radius = -1, bool relative = false);
        public int MoveJointValues(float[] angles, float speed = 0, float acc = 0, float mvtime = 0, bool wait = false, float timeout = NO_TIMEOUT, float radius = -1, bool relative = false)
        {
            return XArmAPI.set_servo_angle(angles, speed, acc, mvtime, wait, timeout, radius, relative);
        }
        
        // move_gohome(float speed = 0, float acc = 0, float mvtime = 0, bool wait = false, float timeout = NO_TIMEOUT);
        public int MoveHome(float speed = 0.0F, float acc = 0.0F, float mvtime = 0.0F, bool wait = false, float timeout = NO_TIMEOUT)
        {
            return XArmAPI.move_gohome(speed, acc, mvtime, wait, timeout);
        }

        //public static int set_position(float[] pose, float radius = -1, bool wait = false, float timeout = NO_TIMEOUT, bool relative = false)
        public int MoveBase(float[] pose, float radius = -1, bool wait = false, float timeout = NO_TIMEOUT, bool relative = false)
        {
            return XArmAPI.set_position(pose, radius, wait, timeout, relative);
        }

        //public static int set_position(float[] pose, bool wait = false, float timeout = NO_TIMEOUT, bool relative = false)
        public int MoveBase(float[] pose, bool wait = false, float timeout = NO_TIMEOUT, bool relative = false)
        {
            return XArmAPI.set_position(pose, wait, timeout, relative);
        }

        //public static int set_tool_position(float[] pose, bool wait = false, float timeout = NO_TIMEOUT)
        public int MoveTool(float[] pose, bool wait = false, float timeout = NO_TIMEOUT)
        {
            return XArmAPI.set_tool_position(pose, wait, timeout);
        }

        // Inverse Kinematics
        public int GetInverseKinematics(float[] pose, float[] angles)
        {
            return XArmAPI.get_inverse_kinematics(pose, angles);
        }
        // Forward Kinematics
        public int Get_ForwardKinematics(float[] angles, float[] pose)
        {
            return XArmAPI.get_forward_kinematics(angles, pose);
        }
        
        //public static int set_servo_angle(float[] angles, bool wait = false, float timeout = NO_TIMEOUT, float radius = -1, bool relative = false)


        }
}
