#include <WiFiNINA.h>
#include "DHT.h"

#define measurePin A4
#define MQ4Pin A1
#define MQ9Pin A2
#define MQ135Pin A7
#define MG811Pin A3
#define KY_A_PIN A0

#define DHTPIN 3
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

float mapFloat(float x, float in_min, float in_max, float out_min, float out_max) {
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

float readNoiseLevel() {
  int minSound = 1023;
  int maxSound = 0;

  for (int i = 0; i < 100; i++) {
    int val = analogRead(KY_A_PIN);
    minSound = min(minSound, val);
    maxSound = max(maxSound, val);
    delay(1);
  }

  int peakToPeak = maxSound - minSound;
  float voltage = peakToPeak * (5.0 / 1023.0);
  return 20 * log10((voltage / 0.005) + 1);
}

void setup() {
  Serial.begin(9600);
  dht.begin();
  Serial.println("=== SENSOR CALIBRATED OUTPUT ===");
}

void loop() {
  int mq4Raw = analogRead(MQ4Pin);
  int mq9Raw = analogRead(MQ9Pin);
  int mq135Raw = analogRead(MQ135Pin);
  int dustRaw = analogRead(measurePin);
  int mgRaw = analogRead(MG811Pin);

  float mq4PPM_calibrated = mapFloat(mq4Raw, 0, 381, 0, 350);
  float mq9PPM = mapFloat(mq9Raw, 0, 630, 0, 10);
  float mq135PPM = mapFloat(mq135Raw, 0, 1023, 0, 2000);

  float noiseDB = readNoiseLevel();
  float humidity = dht.readHumidity();
  float tempC = dht.readTemperature();

  Serial.println("\n--- ENVIRO-DATA (PPM) ---");

  Serial.print("MQ4 (Methane): ");
  Serial.print(mq4PPM_calibrated, 2);
  Serial.println(" ppm");

  Serial.print("MQ9 (CO): ");
  Serial.print(mq9PPM, 2);
  Serial.println(" ppm");

  Serial.print("MQ135 (Air Quality): ");
  Serial.print(mq135PPM, 2);
  Serial.println(" ppm (CO2 eq)");

  Serial.print("Noise: ");
  Serial.print(noiseDB, 2);
  Serial.println(" dB");

  Serial.print("Temp/Hum: ");
  Serial.print(tempC);
  Serial.print("C / ");
  Serial.print(humidity);
  Serial.println("%");

  delay(2000);
}