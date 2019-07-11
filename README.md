## HotNest

HotNest is an Arduino-based datalogger.


## Disclaimer
The code and hardware prototype were done in 2011 for a community project with the aim to collect temperature-map data from the honeybee winter cluster. There were no much development since then. My implementation of hardware prototype is still working nowadays (in 2019).



## Sketches and scripts

### Hotnest.pde
The main part is Hotnest.pde sketch for Arduino board. It works as datalogger for array of temperature sensors installed in a beehive.

It currently uses next libraries (besides those distributed with arduino): 

* DS1307 - http://code.google.com/p/libds1307/ GNU General Public License v3
* FAT16  - http://code.google.com/p/fat16lib/  GNU General Public License v3
  * by William Greiman
* OneWire - bsd-like license TODO: give a link
* PString - http://arduiniana.org/libraries/PString GNU LGPL
* nokia_3310_lcd - possible authors are requested for license


### FillEEPROM.pde
FillEEPROM.pde is a sketch that allows to scan address of a sensor (DS18B20 returns 8 bytes as a unique address) and write it into EEPROM. It saves program memory we need for other stuff. :)

### Farm
This part will include server side script to accept data from serial port (USB) and log it into files (or database).
 

