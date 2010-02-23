/* Hotnest.pde datalogging sketch 
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
 
 
#include <WProgram.h>
#include <avr/pgmspace.h>
#include <EEPROM.h>
#include <Fat16.h>
#include <Fat16util.h> // use functions to print strings from flash memory
#include <OneWire.h>
#include "nokia_3310_lcd.h"
#include <PString.h>
#include <Wire.h>
//#include <DS1307.h> commented out - not enough memory..

Nokia_3310_lcd lcd = Nokia_3310_lcd();
char buffer[5];
PString tempr_str(buffer, sizeof(buffer));

int tempr;

OneWire  ow(5);  //addresses of sensors are in EEPROM

/*
byte sensors[][8] PROGMEM = {
    {0x28, 0xD4, 0x64, 0x72, 0x02, 0x00, 0x00, 0xE8},
     {0x28, 0x48, 0xD1, 0x72, 0x02, 0x00, 0x00, 0xB9}
};
*/

SdCard card;
Fat16 file;

byte inSerByte = 0;

// store error strings in flash to save RAM
#define error(s) error_P(PSTR(s))
void error_P(const char *str)
{
    PgmPrint("e ");
    SerialPrintln_P(str);
    if (card.errorCode) {
        PgmPrint("SD e ");
        Serial.println(card.errorCode, HEX);
    }
    while(1);
}

void writeToScratchpad(byte* address){
    //reset the bus
    ow.reset();
    //select our sensor
    ow.select(address);
    //CONVERT T function call (44h) which puts the temperature into the scratchpad
    ow.write(0x44,0);
    //sleep a second for the write to take place
    delay(1000);
}

void startConversion(void) {
    //reset the bus
    ow.reset();
    //skip selecting particular sensor
    ow.skip();
    //CONVERT T function call to all sensors on the bus
    ow.write(0x44,0);
    //sleep a second for the write to take place
    delay(1000);
}
 
void readFromScratchpad(byte* address, byte* data){
    //reset the bus
    ow.reset();
    //select our sensor
    ow.select(address);
    //read the scratchpad (BEh)
    ow.write(0xBE);
    for (byte i=0;i<9;i++){
        data[i] = ow.read();
    }
}

/*
 * Get temperature from particular sensor
 *  sensor address is retrieved from EEPROM array
 * returns raw 2 byte temperature value   
 * 
 */
int getTemperature(byte sensor_num){
    int t;  // raw temperature
    byte address[8];
    byte data[12];

    for (byte i=0; i<8; i++){
        address[i] = EEPROM.read((int)(sensor*8+i));
    }

    //writeToScratchpad(address);
    readFromScratchpad(address,data);
    //FIXME: are we checking that crc is OK?
    t = data[1]*256 + data[0];
    return t;
}

int tmp;
char fname[] = "HOTNEST.RAW";
  
void setup(void)
{
    Serial.begin(9600);
    delay(20000);
    Serial.print("F1:");
    Serial.println(FreeRam());
    lcd.LCD_3310_init();
    lcd.LCD_3310_clear();

    PgmPrintln("Type any");
    while (!Serial.available());

    // initialize the SD card
    if (!card.init()) error("sd.ini");

    // initialize a FAT16 volume
    if (!Fat16::init(card)) error("F16::ini");

    PgmPrint("Add to: ");
    Serial.println(fname);

    file.writeError = false;

    if (!file.open(fname, O_CREAT | O_APPEND | O_WRITE)) error("open");
    file.println("");
    file.println("Start:");
    Serial.print("F2:");
    Serial.println(FreeRam());
}

void loop(void){
    if (Serial.available()>0) {
        inSerByte = Serial.read();
        if (inSerByte=='c') {
            // close command
            PgmPrint("Stop.");
            file.print("Stop.");
            file.close();
            while(1);
        } 
    }
 
    //Serial.print(RTC.get(DS1307_YR,true)); //read year

    file.print(millis());
    startConversion();
    Serial.print(millis());
    for (byte sensor_num=0; sensor_num<3; sensor_num++) {
        tempr = getTemperature(sensor_num);
        // output value from 2nd sensor on lcd.
        if (sensor_num==2) {
            tempr_str.begin();
            tempr_str.print(tempr);
            //TODO: buffer is pointer to tempr_str. Look how to use tempr_str in the first place.
            lcd.LCD_3310_write_string(5, 5, buffer, MENU_NORMAL );          }
        file.print(";");
        file.print(tempr);
        PgmPrint(";");
        Serial.print(tempr);
    }
    Serial.print(";");
    Serial.print(millis());
    file.println();
    Serial.println();
    Serial.print("FR:");
    Serial.println(FreeRam());
    delay(15000);
}
