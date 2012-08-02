// 
//    FILE: sensor_data.h
// VERSION: 0.1
// PURPOSE: wrapper class for sensor data processing
// LICENSE: GPL v3 (http://www.gnu.org/licenses/gpl.html)
//
// HISTORY:
// Alexander Nikolaev -- original version
// see sensor_data.cpp file
// 

#ifndef sensors_h
#define sensors_h

#if defined(ARDUINO) && (ARDUINO >= 100)
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#define SENSOR_DATA_VERSION "0.1"
#include "dht11.h"
#include <EEPROM.h>


class Sensors
{
public:
    unsigned int dust1;
    unsigned int dust2;
    int humidity;
    int temperature;
    unsigned char start_counter;
    int heater_status;
    unsigned long data_counter;
    
    Sensors();
    String to_json();
    boolean from_dc1100(String s);
    boolean from_dht11(int t, int h);
    boolean has_news(unsigned long *counter);
};
#endif
//
// END OF FILE
