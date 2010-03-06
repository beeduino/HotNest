/* FillEeprom.pde sketch manages addresses of DS18B20 sensors
 * in EEPROM.
 * Copyright (C) 2009-2010 by Dmitry Sorokin
 *
 * This file is part of Beeduino Project
 *
 * Beeduino is free software; you can redistribute it
 * and/or modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3, or (at your option) any later version.
 *
 * Beeduino is distributed in the hope that it will be
 * useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the Beeduino Project; see the file COPYING.  If not, see
 * <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include <EEPROM.h>
#include <OneWire.h>

/* DS18S20 Temperature chip i/o */
OneWire  ds(5);  // on pin 5

byte sensor_num;

byte ch;
char serial_str[4];
int received;

void setup(void) {
    Serial.begin(9600);
    delay(10000);
}

void loop(void) {
    byte i;
    byte present = 0;
    byte data[12];
    byte addr[8];

    received = 0;
    sensor_num = -1;
  
    if ( !ds.search(addr)) {
        Serial.print("No more addresses.\n");
        ds.reset_search();
        delay(250);
        return;
    }
  
    Serial.print("Address: ");
    for( i = 0; i < 8; i++) {
        Serial.print(addr[i], HEX);
        Serial.print(" ");
    }
    Serial.println();
    if ( OneWire::crc8( addr, 7) != addr[7]) {
        Serial.print("CRC is not valid!\n");
        return;
    }
    Serial.print("Assign serial number for that sensor: ");
    while (!Serial.available()>0);
    while (Serial.available()) {
        serial_str[received++] = Serial.read();
        serial_str[received] = '\0';
        delay(10);
    }
    Serial.println(serial_str);
    sensor_num = atoi(serial_str);      // atoi returns 0 if error
    // TODO: Add check for sensor_num is actually equal 0
    if (sensor_num>0) {
        for (i=0; i<8; i++) {
            EEPROM.write((int)(sensor_num*8+i), addr[i]);
        }
    } 
    else if (serial_str[0]=='e')      // EEPROM print
    {  
        Serial.println("EEPROM table:");
        for (i=0; i<40; i++) {
            for (byte j=0; j<8; j++) {
                Serial.print(EEPROM.read((int)(i*8+j)), HEX);
                Serial.print(" ");
            }
            Serial.println();
        }
    } 
    else if (serial_str[0]=='s')      // Skip sensor
    {
        Serial.println("Skip..");
    }

    delay(10000);    
}

