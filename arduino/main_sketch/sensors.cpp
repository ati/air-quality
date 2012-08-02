//
//    FILE: sensors.cpp
// VERSION: 0.1

#include "sensors.h"


Sensors::Sensors()
{
  // increment program restart counter
  start_counter = EEPROM.read(0) + 1;
  EEPROM.write(0, start_counter);
  
  dust1 = 0;
  dust2 = 0;
  humidity = 0;
  temperature= 0;
  heater_status = LOW;
  data_counter = 0;
}


boolean Sensors::from_dht11(int t, int h)
{
  humidity = h;
  temperature = t;
  return true;
}


boolean Sensors::from_dc1100(String s)
{
    // Serial.println(s);
    char sensor_chars[16];
    int comma_pos = s.indexOf(',');
    if (comma_pos > 0)
    {
        s.substring(0, comma_pos+1).toCharArray(sensor_chars, comma_pos+1);
        dust1 = atoi(sensor_chars);
        s.substring(comma_pos+1).toCharArray(sensor_chars, s.length() - comma_pos);
        dust2 = atoi(sensor_chars);
        data_counter++;
        return true;
    }
    else { return false; }
}


boolean Sensors::has_news(unsigned long *counter)
{
    if (data_counter > *counter)
    {
        *counter = data_counter;
        return true;
    }
    else { return false; }
}


//
// END OF FILE
//
