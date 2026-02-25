/*
 * BumpBox MQTT Test — ESP32-S3-WROOM-1
 *
 * Minimal firmware: connects to WiFi + MQTT broker,
 * subscribes to "bumpbox/led" topic, toggles RGB NeoPixel at GPIO 38.
 *
 * Test from browser: http://localhost:8080/api/led/on
 */

#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <Adafruit_NeoPixel.h>

// ====================== CONFIGURATION ======================
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* MQTT_BROKER = "broker.hivemq.com";
const int   MQTT_PORT   = 1883;
const char* MQTT_TOPIC  = "bumpbox/led";

#define RGB_PIN    38   // NeoPixel RGB LED on this board
#define NUM_PIXELS  1
#define MQTT_RECONNECT_MS 5000

// ====================== GLOBALS ======================
WiFiClient   espClient;
PubSubClient mqttClient(espClient);
Adafruit_NeoPixel pixel(NUM_PIXELS, RGB_PIN, NEO_GRB + NEO_KHZ800);
unsigned long lastMqttReconnect = 0;

// ====================== MQTT ======================

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  char message[length + 1];
  memcpy(message, payload, length);
  message[length] = '\0';

  Serial.printf("[MQTT] Received on '%s': %s\n", topic, message);

  if (strcmp(topic, MQTT_TOPIC) == 0) {
    if (strcmp(message, "on") == 0) {
      pixel.setPixelColor(0, pixel.Color(0, 255, 0));  // Green
      pixel.show();
      Serial.println("[MQTT] LED ON (green)");
    } else if (strcmp(message, "off") == 0) {
      pixel.setPixelColor(0, pixel.Color(0, 0, 0));    // Off
      pixel.show();
      Serial.println("[MQTT] LED OFF");
    }
  }
}

void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED) return;

  String clientId = "bumpbox-esp32-" + String(random(0xFFFF), HEX);
  Serial.printf("[MQTT] Connecting to %s:%d as %s...\n",
                MQTT_BROKER, MQTT_PORT, clientId.c_str());

  if (mqttClient.connect(clientId.c_str())) {
    Serial.println("[MQTT] Connected!");
    mqttClient.subscribe(MQTT_TOPIC, 1);
    Serial.printf("[MQTT] Subscribed to: %s\n", MQTT_TOPIC);
  } else {
    Serial.printf("[MQTT] Failed, rc=%d. Will retry in %ds\n",
                  mqttClient.state(), MQTT_RECONNECT_MS / 1000);
  }
}

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

// ====================== SETUP & LOOP ======================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("====================================");
  Serial.println("  BumpBox MQTT Test (ESP32-S3)");
  Serial.println("  RGB NeoPixel on GPIO 38");
  Serial.println("====================================");
  Serial.println();

  pixel.begin();
  pixel.setBrightness(50);
  pixel.show();  // Start with LED off

  connectWiFi();

  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  connectMQTT();

  Serial.println("[Ready] Listening for MQTT commands...\n");
}

void loop() {
  // MQTT: maintain connection and process messages
  if (!mqttClient.connected()) {
    unsigned long now = millis();
    if (now - lastMqttReconnect > MQTT_RECONNECT_MS) {
      lastMqttReconnect = now;
      connectMQTT();
    }
  }
  mqttClient.loop();

  delay(50);
}
