#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ====================== CONFIGURATION ======================
const char* WIFI_SSID     = "Galaxy S23 Ultra E934";
const char* WIFI_PASSWORD = "passswoed";

// const char* SOLENOID_STATE_URL = "http://bumpbox-env-1.eba-43hmmxwt.ap-southeast-1.elasticbeanstalk.com/api/solenoid/state";
const char* SOLENOID_STATE_URL = "http://10.252.191.158:8080/api/solenoid/state";

#define SWITCH_PIN     21    // Microswitch NO terminal
#define RELAY_PIN      16    // Relay IN pin
#define DEBOUNCE_MS    50    // Debounce time (ms)
#define LID_DELAY_MS   500   // Wait for lid to fully settle on switch (ms)
#define SOLENOID_ON_MS 2000  // How long solenoid stays active (ms)
#define POLL_INTERVAL  5000  // Poll backend every 5 seconds

#define RELAY_ON  LOW
#define RELAY_OFF HIGH

// ====================== GLOBALS ======================
int lastSteadyState      = HIGH;
int lastFlickerableState = HIGH;
int currentState;
unsigned long lastDebounceTime = 0;
unsigned long lastPollTime = 0;
bool solenoidBackendOn = false;

// ====================== WIFI ======================
void connectWiFi() {
  Serial.print("[WiFi] Connecting to ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > 15000) {
      Serial.println("\n[WiFi] Connection timed out!");
      return;
    }
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("[WiFi] Connected! IP: ");
  Serial.println(WiFi.localIP());
}

// ====================== POLLING ======================
void checkSolenoidState() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    return;
  }

  HTTPClient http;
  http.begin(SOLENOID_STATE_URL);
  http.setTimeout(5000);

  int httpCode = http.GET();
  if (httpCode == 200) {
    String payload = http.getString();
    StaticJsonDocument<128> doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (!error) {
      bool newState = doc["solenoidOn"] | false;
      if (newState != solenoidBackendOn) {
        solenoidBackendOn = newState;
        Serial.printf("[Backend] Solenoid state changed to: %s\n", solenoidBackendOn ? "ON" : "OFF");
        
        if (solenoidBackendOn) {
          Serial.println("[Action] Activating solenoid from backend trigger...");
          digitalWrite(RELAY_PIN, RELAY_ON);
        } else {
          Serial.println("[Action] Deactivating solenoid from backend trigger...");
          digitalWrite(RELAY_PIN, RELAY_OFF);
        }
      }
    }
  } else {
    Serial.printf("[HTTP] GET failed, error: %s\n", http.errorToString(httpCode).c_str());
  }
  http.end();
}

// ====================== SETUP & LOOP ======================
void setup() {
  Serial.begin(115200);
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF); // Solenoid OFF at boot

  connectWiFi();
  Serial.println("[Ready] Monitoring switch and polling backend...");
}

void loop() {
  // 1. Backend Polling
  if (millis() - lastPollTime > POLL_INTERVAL) {
    lastPollTime = millis();
    checkSolenoidState();
  }

  // 2. Physical Switch Logic (Local Override/Trigger)
  currentState = digitalRead(SWITCH_PIN);

  if (currentState != lastFlickerableState) {
    lastDebounceTime = millis();
    lastFlickerableState = currentState;
  }

  if ((millis() - lastDebounceTime) > DEBOUNCE_MS) {
    // Switch CLOSED → lid pressed down (HIGH → LOW)
    if (lastSteadyState == HIGH && currentState == LOW) {
      Serial.println("Switch closed — waiting for lid to settle...");
      delay(LID_DELAY_MS);

      Serial.println("Activating solenoid (Local)...");
      digitalWrite(RELAY_PIN, RELAY_ON);   // Solenoid ON
      delay(SOLENOID_ON_MS);               // Hold for 2 seconds
      
      // Return to backend state if it was OFF
      if (!solenoidBackendOn) {
        digitalWrite(RELAY_PIN, RELAY_OFF);
        Serial.println("Solenoid deactivated (Local).");
      } else {
        Serial.println("Solenoid remains ON (Backend active).");
      }
    }
    lastSteadyState = currentState;
  }
}
