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
}


boolean Sensors::from_dht11(int t, int h)
{
  humidity = h;
  temperature = t;
  return true;
}


boolean Sensors::from_dc1100(int small, int large)
{
  dust1 = small;
  dust2 = large;
  return true;
}



//
// END OF FILE
//
