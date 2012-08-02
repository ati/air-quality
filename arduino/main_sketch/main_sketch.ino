// vim: filetype=c
#include "sensors.h"
#include "TimerOne.h"
#include "dht11.h"
#include <EEPROM.h>
#include <SoftwareSerial.h>

#define PIN_DHT 10
#define PIN_RAIN 2
#define PIN_HEATER 12
#define PIN_LED 13
#define PIN_XBEE_RX 8
#define PIN_XBEE_TX 9

#define HEATER_ON HIGH
#define HEATER_OFF LOW
#define HEATER_ON_HUMIDITY 80
#define HEATER_OFF_HUMIDITY 60
#define HUMIDITY_POLL_PERIOD 1000000 // 1 sec.

#define DC1100_SERIAL_BAUD 9600
#define XBEE_SERIAL_BAUD 38400

union timechars_union
{
    unsigned int itime;
    unsigned char ctime[2];
} timechars;


SoftwareSerial xbee(PIN_XBEE_RX, PIN_XBEE_TX);
Sensors sensor;
dht11 th_sensor;
// if sensor data has version > known_data_version, it's nessesary to send data to server.
unsigned long known_data_version = 0;

String dc1100_msg;

// rain sensor gives 50ms impulse for each unit of rain bucket
// see docs/rain_rg-11_instructions.pdf for details
volatile long rain_gauge = 0;
void rain_callback() { rain_gauge++; }


void timer1_callback()
{
  set_heater();
}


void set_heater()
{
  if ((HEATER_ON == sensor.heater_status) && (sensor.humidity < HEATER_OFF_HUMIDITY))
  {
    sensor.heater_status = HEATER_OFF;
    digitalWrite(PIN_HEATER, HEATER_OFF);
    digitalWrite(PIN_LED, LOW);
  }
  else if ((HEATER_OFF == sensor.heater_status) && (sensor.humidity > HEATER_ON_HUMIDITY))
  {
    sensor.heater_status = HEATER_ON;
    digitalWrite(PIN_HEATER, HEATER_ON);
    digitalWrite(PIN_LED, HIGH);
  }
}


void serialEvent()
{
  while (Serial.available())
  {
    char c = (char)Serial.read();
    dc1100_msg += c;
    if ('\n' == c) {
        sensor.from_dc1100(dc1100_msg);
        dc1100_msg = "";
    }
  }
}


void send_data_to_server()
{
  xbee.print("{");
  xbee.print("\"d1\":");
  xbee.print(sensor.dust1);
  xbee.print(",\"d2\":");
  xbee.print(sensor.dust2);
  xbee.print(",\"t1\":");
  xbee.print(sensor.temperature);
  xbee.print(",\"h1\":");
  xbee.print(sensor.humidity);  
  xbee.print(",\"rc\":");
  xbee.print(rain_gauge);
  xbee.print(",\"pc\":");
  xbee.print(sensor.start_counter);
  xbee.print(",\"ts\":");
  xbee.print(millis());
  xbee.print(",\"hs\":");
  xbee.print(sensor.heater_status);
  xbee.println("}");
}


void setup()
{  
  dc1100_msg.reserve(16);

  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_HEATER, OUTPUT);
  pinMode(PIN_RAIN, INPUT);
  digitalWrite(PIN_RAIN, HIGH);       // turn on pullup resistors
  
  Timer1.initialize(HUMIDITY_POLL_PERIOD);    // initialize timer1, and set a 1/2 second period 
  Timer1.attachInterrupt(timer1_callback);  // attaches callback() as a timer overflow interrupt
  
  Serial.begin(DC1100_SERIAL_BAUD);
  xbee.begin(XBEE_SERIAL_BAUD);
  xbee.println(String("# start_counter: ") + sensor.start_counter);
  attachInterrupt(0, rain_callback, RISING); //count 50ms pulses for rain gauging 
}


void loop()
{
  delay(1000);
  
  // update temperature and humidity
  int res = th_sensor.read(PIN_DHT);
  if ( DHTLIB_OK == res )
  {
    sensor.from_dht11(th_sensor.temperature, th_sensor.humidity);
  }
  else {
    xbee.println("# dht11_error");
    digitalWrite(PIN_LED, digitalRead(PIN_LED) ^ 1);
  } // blink led in case of error
  
  if (sensor.has_news(&known_data_version))
  {
    send_data_to_server();
  }
}
