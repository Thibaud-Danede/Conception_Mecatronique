/*********************************
* Simple led blinking and Serial link
*     
* Board : Uno    
* Author : O. Patrouix ESTIA
* Date : 01/02/2020
*********************************/

#define BaudRate 115200

// constants won't change. Used here to 
// set pin numbers:
const int ledPin13 =  13;      // the number of the LED pin
// Variables will change:
int ledState13 = HIGH;             // ledState used to set the LED
long previousMillis = 0;        // will store last time LED was updated

// the folHIGH variables is a long because the time, measured in miliseconds,
// will quickly become a bigger number than can be stored in an int.
long intervalMillis = 500;            // interval at which to blink (millisseconds)

// Serial link data
String inputString = "";        // a string to hold incoming data
boolean stringComplete = false; // whether the string is complete

// Mesure
float Mesure;

void setup() {
  Mesure = 2.0;
  // set the digital pin as output:
  pinMode(ledPin13, OUTPUT); 
  // initialize serial:
  Serial.begin(BaudRate);
  // reserve 200 bytes for the inputString
  inputString.reserve(200);
  // BOOT Message
  Serial.write("BOOT Force Serial\r\n");
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
    if (ledState13 == HIGH)
      ledState13 = LOW;
    else
      ledState13 = HIGH;
    // set the LED with the ledState of the variable:
    digitalWrite(ledPin13, ledState13);
    }
}
  
void loop()
{
  // Blink Led still alive
  BlinkLed(intervalMillis);
  // here is where you'd put code that needs to be running all the time.

  // Measurement simulation 
  if (Mesure < 100)
    Mesure += 0.05;
  else
    Mesure = -100;

  // print the string when a newline arrives:
  if (stringComplete) {
    if (inputString.charAt(0)=='M')
    {
      Serial.print("Reading: ");
      Serial.print(Mesure, 3);
      Serial.print(" Kg\r\n");
    }
     // clear the string:
    inputString = "";
    stringComplete = false;
  }
}

/*
  SerialEvent occurs whenever a new data comes in the
 hardware serial RX.  This routine is run between each
 time loop() runs, so using delay inside loop can delay
 response.  Multiple bytes of data may be available.
 */
void serialEvent() {
    // get the new byte:
    char inChar = (char)Serial.read(); 
    // add it to the inputString:
    inputString += inChar;
    // if the incoming character is a newline, set a flag
    // so the main loop can do something about it:
    if (inChar == '\n') {
      stringComplete = true;
    } 
}
