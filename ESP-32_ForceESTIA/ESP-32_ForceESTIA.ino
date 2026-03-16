/*
 Example using the SparkFun HX711 breakout board with a scale
 By: Nathan Seidle
 SparkFun Electronics
 Date: November 19th, 2014
 License: This code is public domain but you buy me a beer if you use this and we meet someday (Beerware license).
 
 This is the calibration sketch. Use it to determine the calibration_factor that the main example uses. It also
 outputs the zero_factor useful for projects that have a permanent mass on the scale in between power cycles.
 
 Setup your scale and start the sketch WITHOUT a weight on the scale
 Once readings are displayed place the weight on the scale
 Press +/- or a/z to adjust the calibration_factor until the output readings match the known weight
 Use this calibration_factor on the example sketch
 
 This example assumes pounds (lbs). If you prefer kilograms, change the Serial.print(" lbs"); line to kg. The
 calibration factor will be significantly different but it will be linearly related to lbs (1 lbs = 0.453592 kg).
 
 Your calibration factor may be very positive or very negative. It all depends on the setup of your scale system
 and the direction the sensors deflect from zero state

 This example code uses bogde's excellent library: https://github.com/bogde/HX711
 bogde's library is released under a GNU GENERAL PUBLIC LICENSE

 ESP-32 pin
 2 -> HX711 CLK
 3 -> DOUT
 5V -> VCC
 GND -> GND
 
 Most any pin on the Arduino Uno will be compatible with DOUT/CLK.
 
 The HX711 board can be powered from 2.7V to 5V so the Arduino 5V power should be fine.
 
*/

#include "HX711.h" //This library can be obtained here http://librarymanager/All#Avia_HX711

// Sensor Type uncomment your choice
//#define Factor 43400 //50Kg max scale setup
#define Factor 72500 //100Kg max scale setup
// Serial link
#define BaudRate 115200
// Load Cell Pins & Object
#define LOADCELL_DOUT_PIN  16
#define LOADCELL_SCK_PIN  17
HX711 scale;
// Calibration
float calibration_factor = Factor; //50Kg max scale setup
long zero_factor = 0;
boolean CalMsgFlag = true;
boolean UnitFlag = true;
char ScaleCMD = ' ';

// constants won't change. Used here to 
// set pin numbers:
const int ledPin =  2;      // the number of the LED pin
// Variables will change:
int ledState = HIGH;             // ledState used to set the LED
long previousMillis = 0;        // will store last time LED was updated
long intervalMillis = 500;            // interval at which to blink (millisseconds)

// Serial link data
String inputString = "";        // a string to hold incoming data
boolean stringComplete = false; // whether the string is complete

void setup() {
  // set the digital pin as output:
  pinMode(ledPin, OUTPUT);

    // initialize serial:
  Serial.begin(BaudRate);
  // reserve 200 bytes for the inputString
  inputString.reserve(200);
  // BOOT Message
  Serial.write("BOOT Force Sensor\n");
  Serial.write("CMD :\n");
  Serial.write("  - C : Calibration\n");
  Serial.write("  - Q : Quit Calibration\n");
  Serial.write("  - T : Tare\n");
  Serial.write("  - U : Unit Change\n");
  Serial.write("  - M : Measurement\n");
 // Scale Definition
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
}

/*
  SerialRead is called in loop(), so using delay inside loop can delay
 response.  Multiple bytes of data may be available.
 */
void serialRead() {
    char inChar;
    while (Serial.available()) {
      // get the new byte:
      inChar = (char)Serial.read(); 
      // add it to the inputString:
      inputString += inChar;
      // if the incoming character is a newline, set a flag
      // so the main loop can do something about it:
      if (inChar == '\n') {
         stringComplete = true;
      }
    } 
}

// Blink Led on ledPin13
// 50% duty cycle
// intervalMillis is 1/2 period
void BlinkLed(long intervalMillis){
  // check to see if it's time to blink the LED; that is, if the 
  // difference between the current time and last time you blinked 
  // the LED is bigger than the interval at which you want to 
  // blink the LED.
  unsigned long currentMillis = millis();
  
  if(currentMillis - previousMillis > intervalMillis) {
    // save the last time you blinked the LED 
    previousMillis = currentMillis;   
    // if the LED is off turn it on and vice-versa:
    if (ledState == HIGH)
      ledState = LOW;
    else
      ledState = HIGH;
    // set the LED with the ledState of the variable:
    digitalWrite(ledPin, ledState);
    }
  }

void CalibrationMsg(){
  Serial.println("HX711 calibration sketch");
  Serial.println("Remove all weight from scale");
  Serial.println("After readings begin, place known weight on scale");
  Serial.println("Press + or a to increase calibration factor");
  Serial.println("Press - or z to decrease calibration factor");

  scale.set_scale();
  scale.tare();	//Reset the scale to 0

  zero_factor = scale.read_average(); //Get a baseline reading
  Serial.print("Zero factor: "); //This can be used to remove the need to tare the scale. Useful in permanent scale projects.
  Serial.println(zero_factor);
  CalMsgFlag = false;
}
void loop() {
  // Blink Led still alive
  BlinkLed(intervalMillis);
   // check Serial link for data
   serialRead();
  // print the string when a newline arrives:
  if (stringComplete) {
    Serial.print(inputString); 
    // ScaleCMD
    ScaleCMD = inputString.charAt(0);
    // clear the string:
    inputString = "";
    stringComplete = false;
  }

  // Parse ScaleCDM
  switch(ScaleCMD){
    case 'C':
    // Calibration Message
    if(CalMsgFlag)
      CalibrationMsg();

    if(!CalMsgFlag){
      scale.set_scale(calibration_factor); //Adjust to this calibration factor

      Serial.print("Reading: ");
      Serial.print(scale.get_units(), 3);
      Serial.print(" Kg"); //Change this to kg and re-adjust the calibration factor if you follow SI units like a sane person
      Serial.print(" calibration_factor: ");
      Serial.print(calibration_factor);
      Serial.println();
    }
      ScaleCMD = 'C';
      break;
    case '+':
    case '-':
    case 'a':
    case 'z':
      if(!CalMsgFlag){
        if(ScaleCMD == '+' || ScaleCMD == 'a')
          calibration_factor += 100;
        else if(ScaleCMD == '-' || ScaleCMD == 'z')
          calibration_factor -= 100;
      }      
      ScaleCMD = 'C';    
      break;
    case 'Q':
      ScaleCMD = ' ';
      CalMsgFlag = true;
      break;
    case 'M':
      Serial.print("Reading: ");
      Serial.print(scale.get_units(), 3);
      if(UnitFlag)
        Serial.print(" Kg\r\n");
      else
        Serial.print(" N\r\n");
      ScaleCMD = ' ';    
      break;
    case 'T':
      scale.tare();	//Reset the scale to 0
      ScaleCMD = ' ';
      break;
     case 'U':
      UnitFlag = !UnitFlag;
      if(UnitFlag)
        scale.set_scale(calibration_factor);
      else
        scale.set_scale(calibration_factor / 9.80);
      ScaleCMD = ' ';
      break;     
    default:
      ScaleCMD = ' ';
      break;   
  }
}


