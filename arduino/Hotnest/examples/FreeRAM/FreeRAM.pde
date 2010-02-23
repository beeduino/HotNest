
#include <Fat16util.h>
#include <Fat16.h>

#include <PString.h>
#include <Wire.h>
#include "DS1307.h"

void setup(void) {
    delay(10000);
    Serial.begin(9600);
    Serial.print("FR:");
    Serial.println(FreeRam());
}

void loop(void) {
    Serial.print("FL:");
    Serial.println(FreeRam());
    delay(5000);
}
