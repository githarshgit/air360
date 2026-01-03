#include <WiFiNINA.h>

#include "DHT.h"


// ------------ PIN DEFINITIONS ------------
#define DUST_PIN   A4
#define MQ4_PIN    A1
#define MQ9_PIN    A2
#define MQ135_PIN  A7
#define MG811_PIN  A3
#define SOUND_PIN  A0

#define DHTPIN 3
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// ------------ SETUP ------------
void setup() {
  Serial.begin(9600);
  dht.begin();
  Serial.println("=== RAW SENSOR VALUE TEST ===");
}

// ------------ LOOP ------------
void loop() {

  // ---- RAW ANALOG READS ----
  int dustRaw   = analogRead(DUST_PIN);
  int mq4Raw    = analogRead(MQ4_PIN);
  int mq9Raw    = analogRead(MQ9_PIN);
  int mq135Raw  = analogRead(MQ135_PIN);
  int mg811Raw  = analogRead(MG811_PIN);
  int soundRaw  = analogRead(SOUND_PIN);

  // ---- DHT ----
  float humidity = dht.readHumidity();
  float tempC = dht.readTemperature();

  // ---- PRINT ----
  Serial.println("\n--- RAW SENSOR VALUES ---");

  Serial.print("Dust Raw   : "); Serial.println(dustRaw);
  Serial.print("MQ4 Raw    : "); Serial.println(mq4Raw);
  Serial.print("MQ9 Raw    : "); Serial.println(mq9Raw);
  Serial.print("MQ135 Raw  : "); Serial.println(mq135Raw);
  Serial.print("MG811 Raw  : "); Serial.println(mg811Raw);
  Serial.print("Sound Raw : "); Serial.println(soundRaw);

  Serial.print("Humidity   : ");
  Serial.println(isnan(humidity) ? -1 : humidity);

  Serial.print("Temp (C)   : ");
  Serial.println(isnan(tempC) ? -1 : tempC);

  delay(1500);
}
