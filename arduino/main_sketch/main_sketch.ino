#include "TimerOne.h"
#include "dht11.h"

#define PIN_LED 13
#define PIN_HEATER 10
#define HEATER_ON_HUMIDITY 80.0
#define HEATER_OFF_HUMIDITY 60.0
#define PIN_DHT 2
#define HUMIDITY_POLL_PERIOD 10000000 // 10 sec.
#define SERIAL_BAUD 9600

dht11 DHT11;
int heater_status = LOW;

String inputString = "";
boolean input_line_complete = false;

void setup()
{
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_HEATER, OUTPUT);
  
  Timer1.initialize(HUMIDITY_POLL_PERIOD);    // initialize timer1, and set a 1/2 second period             // setup pwm on pin 9, 50% duty cycle
  Timer1.attachInterrupt(humidity_callback);  // attaches callback() as a timer overflow interrupt
  
  Serial.begin(SERIAL_BAUD);
  inputString.reserve(200);
}

void humidity_callback()
{
  // (float)DHT11.temperature // oC
  int res = DHT11.read(PIN_DHT);
  if ( DHTLIB_OK == res ) { set_heater((float)DHT11.humidity); }
  else { digitalWrite(PIN_LED, digitalRead(PIN_LED) ^ 1); } // blink led in case of error
}


void set_heater(float humidity)
{
  if ((HIGH == heater_status) && (humidity < HEATER_OFF_HUMIDITY))
  {
    heater_status = LOW;
    digitalWrite(PIN_HEATER, LOW);
    digitalWrite(PIN_LED, LOW);
  }
  else if ((LOW == heater_status) && (humidity > HEATER_ON_HUMIDITY))
  {
    heater_status = HIGH;
    digitalWrite(PIN_HEATER, HIGH);
    digitalWrite(PIN_LED, HIGH);
  }
}


void serialEvent()
{
  while (Serial.available())
  {
    char inChar = (char)Serial.read();
    inputString += inChar;
    if ('\n' == inChar) { input_line_complete = true; }
  }
}


void loop()
{
  delay(10);
  if (input_line_complete)
  {
    Serial.println(inputString);
    inputString = "";
    input_line_complete = false;
  }
}
