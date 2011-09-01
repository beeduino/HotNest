/* Hotnest.pde is a datalogging sketch 
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
 *
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
#include <DS1307.h> 
//#include <stdio.h>

#define SENSOR_TBL_MAX 36
#define SENSOR_TBL_OFFSET 0

//keypad debounce parameter
#define DEBOUNCE_MAX 15
#define DEBOUNCE_ON  10
#define DEBOUNCE_OFF 3 

#define NUM_KEYS 5

// joystick number
#define UP_KEY 1
#define LEFT_KEY 2
#define CENTER_KEY 4
#define DOWN_KEY 3
#define RIGHT_KEY 0

const int activityLED = 3;

// adc preset value, represent top value,incl. noise & margin,that the adc reads, when a key is pressed
// set noise & margin = 30 (0.15V@5V)
int  adc_key_val[5] ={30, 120, 280, 445, 667 };

// debounce counters
byte button_count[NUM_KEYS];
// button status - pressed/released
byte button_status[NUM_KEYS];
// button on flags for user program 
byte button_flag[NUM_KEYS];

int sensor_to_watch;

Nokia_3310_lcd lcd = Nokia_3310_lcd();

char buffer[5];
PString tempr_str(buffer, sizeof(buffer));

char date_buf[10];
PString date_str(date_buf, sizeof(date_buf));

char time_buf[9];
PString time_str(time_buf, sizeof(time_buf));

// display elements
char sensor_num_str[3];


int tempr;
float current_tempr;

float last_tempr[SENSOR_TBL_MAX];
float avr_tempr[SENSOR_TBL_MAX];
float min_tempr[SENSOR_TBL_MAX];
float max_tempr[SENSOR_TBL_MAX];

int prev_day;
int current_day;

OneWire  ow(5);  //addresses of sensors are in EEPROM

SdCard card;
Fat16 file;

int SD_Ready = 1;

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
    SD_Ready = 0;
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
        address[i] = EEPROM.read((int)(sensor_num*8+i));
    }

    //writeToScratchpad(address);
    readFromScratchpad(address,data);
    //FIXME: are we checking that crc is OK?
    t = data[1]*256 + data[0];
    return t;
}

int tmp;
char fname[] = "HOTNEST.TXT";
  
void setup(void)
{
    // activity_led setup
    pinMode(activityLED, OUTPUT);    

  
    // setup interrupt-driven keypad arrays  
    // reset button arrays
    for(byte i=0; i<NUM_KEYS; i++){
        button_count[i]=0;
        button_status[i]=0;
        button_flag[i]=0;
    }
  
    // Setup timer2 -- Prescaler/256
    TCCR2A &= ~((1<<WGM21) | (1<<WGM20));
    TCCR2B &= ~(1<<WGM22);
    TCCR2B = (1<<CS22)|(1<<CS21);      

    ASSR |=(0<<AS2);

    // Use normal mode  
    TCCR2A =0;    
    //Timer2 Overflow Interrupt Enable  
    TIMSK2 |= (0<<OCIE2A);
    TCNT2=0x6;  // counting starts from 6;  
    TIMSK2 = (1<<TOIE2);    

    SREG|=1<<SREG_I;

    sensor_to_watch = 0;

    Serial.begin(9600);
    lcd.LCD_3310_init();
    lcd.LCD_3310_clear();

    // initialize the SD card
    if (!card.init()) error("sd.ini");

    // initialize a FAT16 volume
    if (!Fat16::init(card)) error("F16::ini");

    file.writeError = false;

    if (!file.open(fname, O_CREAT | O_APPEND | O_WRITE)) error("open");
    file.println("");
    file.println("Start:");
    Serial.print("FR:");
    Serial.println(FreeRam());
    
    //RTC.start();
}

void display_sensor(int sensnum) {
  
    tempr_str.begin();
    tempr_str.print(sensnum);
    lcd.LCD_3310_write_string(1, 5, buffer, MENU_NORMAL );          
    //TODO: buffer is the pointer to the tempr_str string. 
    //TODO: Look how to use tempr_str in the first place.
    tempr_str.begin();
    tempr_str.print(last_tempr[sensnum]);
    lcd.LCD_3310_write_string(30, 5, buffer, MENU_NORMAL );         

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
 
    digitalWrite(activityLED, HIGH); 
    //TODO: RTC commented out - not enough memory
    //TODO: see http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1191209057/104#104
    date_str.begin();
    Serial.print("Date: ");
    date_str.print(RTC.get(DS1307_YR,true)); //read year
    date_str.print("/");
    date_str.print(RTC.get(DS1307_MTH, true));
    date_str.print("/");
    date_str.print(RTC.get(DS1307_DATE, true));
    time_str.begin();
    time_str.print(RTC.get(DS1307_HR, true));
    time_str.print(":");
    time_str.print(RTC.get(DS1307_MIN, true));
    time_str.print(":");
    time_str.println(RTC.get(DS1307_SEC, true));
    Serial.print(date_str);
    Serial.print(" ");
    Serial.println(time_str);
  
    file.print(date_str);
    file.print(" ");
    file.print(time_str);
    file.print(":");
    file.print(millis());
    Serial.print(millis());
    lcd.LCD_3310_write_string(0, 0, " TEMP ", MENU_HIGHLIGHT); 
    lcd.LCD_3310_write_string(36, 0, " SETUP ", MENU_NORMAL);
    lcd.LCD_3310_write_string(0,2, date_buf, MENU_NORMAL);
    lcd.LCD_3310_write_string(0,3, time_buf, MENU_NORMAL);
    startConversion();
    
    for (byte sensor_num=0; sensor_num<SENSOR_TBL_MAX; sensor_num++) {
        tempr = getTemperature(sensor_num);
        current_tempr = tempr * 0.0625;

        last_tempr[sensor_num] = current_tempr;
    }
    
    for (byte sensor_num=0; sensor_num<SENSOR_TBL_MAX; sensor_num++) {
        // output value from 2nd sensor on lcd.
        if (sensor_num==sensor_to_watch) {
            display_sensor(sensor_to_watch);  
        }

        if (sensor_num!=0) {
            file.print(";");
            PgmPrint(";");
        }
        file.print(last_tempr[sensor_num]);
        Serial.print(last_tempr[sensor_num], 2); 
      
    }
    file.println();
    Serial.println(millis());

    //don't sync too often - requires 2048 bytes of I/O to SD card
    if (!file.sync()) error("sync");
    Serial.print("FR:");
    Serial.println(FreeRam());
    
    digitalWrite(activityLED, LOW);

    delay(15000);
}


// The followinging are interrupt-driven keypad reading functions
//  which includes DEBOUNCE ON/OFF mechanism, and continuous pressing detection


// Convert ADC value to key number
char get_key(unsigned int input)
{
	char k;
    
	for (k = 0; k < NUM_KEYS; k++)
	{
		if (input < adc_key_val[k])
		{
            return k;
        }
	}
    if (k >= NUM_KEYS) k = -1;     // No valid key pressed
    return k;
}

void manage_key(byte i){
    switch(i){
        case UP_KEY:
            Serial.println("UP");
            break;  
        case DOWN_KEY:
            Serial.println("DOWN");
            break;
        case LEFT_KEY:
            Serial.println("LEFT");
            sensor_to_watch--;
            if (sensor_to_watch<0){
                sensor_to_watch = SENSOR_TBL_MAX-1;
            }
            display_sensor(sensor_to_watch);
            break;
        case RIGHT_KEY:
            Serial.println("RIGHT");
            sensor_to_watch++;
            if (sensor_to_watch>=SENSOR_TBL_MAX){
                sensor_to_watch = 0;
            }
            display_sensor(sensor_to_watch);
            break;
    }
    button_status[i]=0;
    button_flag[i]=0;
}

void update_adc_key()
{
    int adc_key_in;
    char key_in;
    byte i;

    adc_key_in = analogRead(3);
    key_in = get_key(adc_key_in);
    for(i=0; i<NUM_KEYS; i++)
    {
        if(key_in==i)  //one key is pressed  
        {
            if(button_count[i]<DEBOUNCE_MAX)
            {
                button_count[i]++;
                if(button_count[i]>DEBOUNCE_ON)
                {
                    if(button_status[i] == 0)
                    {
                        button_flag[i] = 1;
                        button_status[i] = 1; //button debounced to 'pressed' status
                    }
                }
            }
            else
                if (button_status[i]==1 and button_flag[i]==1)
                {
                    button_status[i]=0;
                    button_flag[i]=0;
                    Serial.print("bc: ");
                    Serial.println(button_count[i], DEC);
                    manage_key(i);
                }
        }
        else // no button pressed
        {
          if (button_count[i] >0) 
          {
              button_flag[i] = 0;
              button_count[i]--;
              if(button_count[i]<DEBOUNCE_OFF){
                  button_status[i]=0;   //button debounced to 'released' status
              }
          }
        }
    }
}


// Timer2 interrupt routine -
// 1/(160000000/256/(256-6)) = 4ms interval

ISR(TIMER2_OVF_vect) {  
  TCNT2  = 6;
  update_adc_key();
}


