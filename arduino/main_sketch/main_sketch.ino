// vim: filetype=c
#include "sensors.h"
#include "dht11.h"
#include <EEPROM.h>
#include <SoftwareSerial.h>

#define PIN_DHT 10
#define PIN_RAIN 2
#define PIN_HEATER 12
#define PIN_LED 13
#define PIN_XBEE_RX 8
#define PIN_XBEE_TX 9

#define HEATER_ON LOW
#define HEATER_OFF HIGH
#define HEATER_ON_HUMIDITY 85
#define HEATER_OFF_HUMIDITY 80
#define IGNORE_RAIN_PERIOD 100 // milliseconds after last call
#define MAX_UNSIGNED_LONG 4294967295
#define DC1100_POLL_PERIOD 60000 // 1 min

#define DC1100_SERIAL_BAUD 9600
#define XBEE_SERIAL_BAUD 38400


SoftwareSerial xbee(PIN_XBEE_RX, PIN_XBEE_TX);
Sensors sensor;
dht11 th_sensor;


// rain sensor gives 50ms impulse for each unit of rain bucket
// see docs/rain_rg-11_instructions.pdf for details
volatile unsigned long rain_gauge = 0;
volatile unsigned long rain_counted_at = 0;


unsigned long time_diff(unsigned long before, unsigned long after)
{
  return (after >= before)? 
    after - before : after + (MAX_UNSIGNED_LONG - before);
}

void rain_callback()
{
  if (time_diff(rain_counted_at, millis()) > IGNORE_RAIN_PERIOD)
  {
    rain_gauge++;
    rain_counted_at = millis();
  }
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
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_HEATER, OUTPUT);
  pinMode(PIN_RAIN, INPUT);
  digitalWrite(PIN_RAIN, HIGH);       // turn on pullup resistors
  
  Serial.begin(DC1100_SERIAL_BAUD);
  xbee.begin(XBEE_SERIAL_BAUD);

  attachInterrupt(0, rain_callback, RISING); //count 50ms pulses for rain gauging 
  
  delay(2000); // wait for everything to settle down
  xbee.println(String("# start_counter: ") + sensor.start_counter);
}



void loop()
{ 
  char c;
  static char line[80];
  static int i = 0;
  static unsigned long dc1100_polled_at = 0;
  int small, large;

  while ((c = Serial.read()) != -1)
  {
    if (c == '\n')
    {
      line[i++] = 0;
      sscanf(line, "%d,%d", &small, &large);
      sensor.from_dc1100(small, large);
      i = 0;
    }
    else
    {
      line[i++] = c;
    }
  }
  
  if (time_diff(dc1100_polled_at, millis()) >= DC1100_POLL_PERIOD)
  {
    int res = th_sensor.read(PIN_DHT);
    if ( DHTLIB_OK == res )
    {
      sensor.from_dht11(th_sensor.temperature, th_sensor.humidity);
    }
    else {
      xbee.println("# dht11_error");
      digitalWrite(PIN_LED, digitalRead(PIN_LED) ^ 1);
    } // blink led in case of error
  
    send_data_to_server();
    set_heater();
    dc1100_polled_at = millis();
  }
 
  
  delay(100);
}
