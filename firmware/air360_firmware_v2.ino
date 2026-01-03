#include <WiFiNINA.h>
#include <SPI.h>
#include <SD.h>
#include "DHT.h"
#include <math.h>

// ---------------- PINS ----------------
#define measurePin A4
#define MQ4Pin A1
#define MQ9Pin A2
#define MQ135Pin A7
#define MG811Pin A3
#define SoundAnalog A0
#define chipSelect 10
#define ledPower 4
#define ledSuccess 8
#define ledFail 9
#define DHTPIN 3
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// ---------------- DUST SENSOR TIMING ----------------
const unsigned int samplingTime = 280;
const unsigned int deltaTime = 40;
const unsigned int sleepTime = 9680;

// ---------------- SYSTEM ----------------
bool sdAvailable = false;
File logFile;
WiFiServer server(80);

String latestJson;
unsigned long lastReadTime = 0;
const unsigned long readInterval = 3000;

// ---------------- HELPER FUNCTIONS ----------------
float mapFloat(float x, float in_min, float in_max,
               float out_min, float out_max) {
  return (x - in_min) * (out_max - out_min) /
         (in_max - in_min) + out_min;
}

float readNoiseLevel() {
  int minSound = 1023;
  int maxSound = 0;

  for (int i = 0; i < 100; i++) {
    int val = analogRead(SoundAnalog);
    minSound = min(minSound, val);
    maxSound = max(maxSound, val);
    delay(1);
  }

  int peakToPeak = maxSound - minSound;
  float voltage = peakToPeak * (5.0 / 1023.0);
  return 20 * log10((voltage / 0.005) + 1);
}

// ================== SETUP ==================
void setup() {
  Serial.begin(9600);

  pinMode(ledPower, OUTPUT);
  pinMode(ledSuccess, OUTPUT);
  pinMode(ledFail, OUTPUT);
  digitalWrite(ledSuccess, LOW);
  digitalWrite(ledFail, LOW);

  dht.begin();

  Serial.println("=== AIR QUALITY SYSTEM STARTING ===");

  // ---- SD CARD ----
  Serial.print("Initializing SD card... ");
  if (SD.begin(chipSelect)) {
    sdAvailable = true;
    logFile = SD.open("data_log.csv", FILE_WRITE);
    if (logFile && logFile.size() == 0) {
      logFile.println("Timestamp\tCO\tCO2eq\tSOxNOx\tCH4\tNoise\tTemp\tHumidity\tDust\tVoltage");
    }
    logFile.close();
    Serial.println("OK");
  } else {
    Serial.println("FAILED");
    sdAvailable = false;
  }

  // ---- WIFI AP ----
  Serial.print("Starting WiFi AP... ");
  if (!WiFi.beginAP("Air Quality Monitoring", "87654321")) {
    Serial.println("FAILED");
    while (1);
  }
  Serial.println("OK");
  Serial.print("AP IP Address: ");
  Serial.println(WiFi.localIP());

  server.begin();
}

// ================== LOOP ==================
void loop() {
  if (millis() - lastReadTime >= readInterval) {
    latestJson = readSensorDataAsJson();
    lastReadTime = millis();
  }

  WiFiClient client = server.available();
  if (client) {
    String request = client.readStringUntil('\r');
    client.flush();

    if (request.indexOf("GET /data") >= 0) {
      sendHttpResponse(client, latestJson, 200);
    } else {
      sendHttpResponse(client, "{\"error\":\"Use /data\"}", 404);
    }
    client.stop();
  }
}

// ================== SENSOR READ ==================
String readSensorDataAsJson() {
  bool ok = true;

  // ---- DUST ----
  digitalWrite(ledPower, LOW);
  delayMicroseconds(samplingTime);
  float voMeasured = analogRead(measurePin);
  delayMicroseconds(deltaTime);
  digitalWrite(ledPower, HIGH);
  delayMicroseconds(sleepTime);

  float voltage = voMeasured * (5.0 / 1024.0);
  float dustDensity = 5.64 * voltage;

  // ---- MQ RAW ----
  int mq4Raw = analogRead(MQ4Pin);
  int mq9Raw = analogRead(MQ9Pin);
  int mq135Raw = analogRead(MQ135Pin);

  // ---- SAFE PPM MAPPING ----
  float mq4PPM   = constrain(mapFloat(mq4Raw,   100, 900, 100, 3000), 100, 3000);
  float mq9PPM   = constrain(mapFloat(mq9Raw,   100, 900,   0,  100),   0,  100);
  float mq135PPM = constrain(mapFloat(mq135Raw,   0, 900, 400, 1200), 300, 1200);

  // ---- OTHER SENSORS ----
  int mg811Value = analogRead(MG811Pin);
  float mg811Voltage = mg811Value * (1.0 / 1023.0);
  float noiseDB = readNoiseLevel();

  float humidity = dht.readHumidity();
  float tempC = dht.readTemperature()-5;
  float heatIndexC = dht.computeHeatIndex(tempC, humidity, false);

  if (isnan(humidity) || isnan(tempC)) ok = false;

  // ================= SERIAL OUTPUT =================
  Serial.println("\n--- SENSOR READINGS ---");

  Serial.print("Dust Raw: "); Serial.print(voMeasured);
  Serial.print(" | Voltage: "); Serial.print(voltage, 3);
  Serial.print(" | Density: "); Serial.print(dustDensity, 2);
  Serial.println(" mg/m3");

  Serial.print("MQ4 Raw: "); Serial.print(mq4Raw);
  Serial.print(" | Methane: "); Serial.print(mq4PPM, 0);
  Serial.println(" ppm");

  Serial.print("MQ9 Raw: "); Serial.print(mq9Raw);
  Serial.print(" | CO: "); Serial.print(mq9PPM, 1);
  Serial.println(" ppm");

  Serial.print("MQ135 Raw: "); Serial.print(mq135Raw);
  Serial.print(" | Air Quality (CO2 eq): "); Serial.print(mq135PPM, 0);
  Serial.println(" ppm");

  Serial.print("MG811 Raw: "); Serial.print(mg811Value);
  Serial.print(" | Voltage: "); Serial.print(mg811Voltage, 3);
  Serial.println(" V");

  Serial.print("Noise Level: ");
  Serial.print(noiseDB, 1);
  Serial.println(" dB");

  Serial.print("Temperature: ");
  Serial.print(tempC, 1);
  Serial.println(" °C");

  Serial.print("Humidity: ");
  Serial.print(humidity, 1);
  Serial.println(" %");

  // ---- SD LOG ----
  bool sdOK = false;
  if (sdAvailable) {
    logFile = SD.open("data_log.csv", FILE_WRITE);
    if (logFile) {
      logFile.print(millis()); logFile.print("\t");
      logFile.print(mq9PPM,1); logFile.print("\t");
      logFile.print(mq135PPM,0); logFile.print("\t");
      logFile.print("0\t");
      logFile.print(mq4PPM,0); logFile.print("\t");
      logFile.print(noiseDB,1); logFile.print("\t");
      logFile.print(tempC,1); logFile.print("\t");
      logFile.print(humidity,1); logFile.print("\t");
      logFile.print(dustDensity,2); logFile.print("\t");
      logFile.println(voltage,3);
      logFile.close();
      sdOK = true;
    }
  }

  // ---- LED STATUS ----
  digitalWrite(ledSuccess, ok);
  digitalWrite(ledFail, !ok);
  delay(100);
  digitalWrite(ledSuccess, LOW);
  digitalWrite(ledFail, LOW);

  // ---- JSON ----
  String json = "{";
  json += "\"dustDensity\":" + String(dustDensity,2) + ",";
  json += "\"mq4\":" + String(mq4PPM,0) + ",";
  json += "\"mq9\":" + String(mq9PPM,1) + ",";
  json += "\"mq135\":" + String(mq135PPM,0) + ",";
  json += "\"mg811Value\":" + String(mg811Value) + ",";
  json += "\"mg811Voltage\":" + String(mg811Voltage,2) + ",";
  json += "\"sound\":" + String(noiseDB,1) + ",";
  json += "\"humidity\":" + String(humidity,1) + ",";
  json += "\"tempC\":" + String(tempC,1) + ",";
  json += "\"heatIndexC\":" + String(heatIndexC,1) + ",";
  json += "\"sdStatus\":\"" + String(sdAvailable ? (sdOK ? "Inserted" : "Inserted but Error") : "Missing") + "\",";
  json += "\"uptimeMillis\":" + String(millis());
  json += "}";

  return json;
}

// ================== HTTP ==================
void sendHttpResponse(WiFiClient &client, String body, int statusCode) {
  client.print("HTTP/1.1 ");
  client.print(statusCode);
  client.println(statusCode == 200 ? " OK" : " Not Found");
  client.println("Content-Type: application/json");
  client.println();
  client.println(body);
}
