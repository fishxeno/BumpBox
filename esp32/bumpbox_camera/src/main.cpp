/*
 * BumpBox ESP32-CAM — Smart Locker Camera System
 *
 * Captures a JPEG photo of an item inside the locker, sends it to the
 * BumpBox backend for object detection, and prints the result to Serial.
 *
 * Hardware: AI-Thinker ESP32-CAM + ESP32-CAM-MB base board
 * Backend:  POST /detect-object (multipart/form-data)
 *
 * Trigger:  Button on GPIO 13  OR  type 'c' in Serial Monitor
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "esp_camera.h"
#include <ArduinoJson.h>

// ====================== CONFIGURATION ======================
// -- WiFi (change these!) --
const char* WIFI_SSID     = "YOUR_WIFI_SSID";       // <-- Change this
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";    // <-- Change this

// -- Server --
const char* SERVER_URL = "http://bumpbox-env-1.eba-43hmmxwt.ap-southeast-1.elasticbeanstalk.com/detect-object";
const bool  USE_MOCK   = false;  // true = test mode, false = real Google Vision API

// -- Pins --
#define BUTTON_PIN     13   // Trigger button (connect to GND)
#define FLASH_LED_PIN   4   // Onboard white flash LED
#define STATUS_LED_PIN 33   // Small red LED (active LOW)

// -- AI-Thinker ESP32-CAM pin map --
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// -- Camera settings --
#define FRAME_SIZE    FRAMESIZE_VGA  // 640x480
#define JPEG_QUALITY  12             // 0-63, lower = better quality

// -- Timing --
#define DEBOUNCE_MS       300
#define WIFI_TIMEOUT_MS   15000
#define HTTP_TIMEOUT_MS   15000
#define FLASH_WARMUP_MS   150

// ====================== GLOBALS ======================
unsigned long lastButtonPress = 0;

// ====================== FORWARD DECLARATIONS ======================
void flashLED(int times, int durationMs);
void blinkError(int times);
void connectWiFi();
bool initCamera();
void captureAndSend();
bool sendToServer(uint8_t* imageData, size_t imageLen);
void parseResponse(const String& response);

// ====================== LED HELPERS ======================

void flashLED(int times, int durationMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(FLASH_LED_PIN, HIGH);
    delay(durationMs);
    digitalWrite(FLASH_LED_PIN, LOW);
    if (i < times - 1) delay(durationMs);
  }
}

void blinkError(int times) {
  for (int i = 0; i < times; i++) {
    digitalWrite(STATUS_LED_PIN, LOW);   // ON (active LOW)
    delay(150);
    digitalWrite(STATUS_LED_PIN, HIGH);  // OFF
    delay(150);
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
    if (millis() - start > WIFI_TIMEOUT_MS) {
      Serial.println("\n[WiFi] Connection timed out!");
      Serial.println("[WiFi] Check SSID/password. ESP32 only supports 2.4GHz WiFi.");
      blinkError(3);
      return;
    }
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("[WiFi] Connected! IP: ");
  Serial.println(WiFi.localIP());
}

// ====================== CAMERA ======================

bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode    = CAMERA_GRAB_LATEST;

  if (psramFound()) {
    config.frame_size  = FRAME_SIZE;
    config.jpeg_quality = JPEG_QUALITY;
    config.fb_count    = 2;
    config.fb_location = CAMERA_FB_IN_PSRAM;
    Serial.println("[Camera] PSRAM found — using double buffer");
  } else {
    config.frame_size  = FRAMESIZE_SVGA;
    config.jpeg_quality = 14;
    config.fb_count    = 1;
    config.fb_location = CAMERA_FB_IN_DRAM;
    Serial.println("[Camera] No PSRAM — using reduced settings");
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[Camera] Init failed (0x%x)\n", err);
    Serial.println("[Camera] Fix: ensure 5V power supply. Try adding a capacitor.");
    return false;
  }

  // Tune sensor for dark locker interior
  sensor_t* s = esp_camera_sensor_get();
  if (s) {
    s->set_brightness(s, 1);
    s->set_whitebal(s, 1);
    s->set_awb_gain(s, 1);
    s->set_aec2(s, 1);
    s->set_ae_level(s, 1);
    s->set_gainceiling(s, (gainceiling_t)GAINCEILING_8X);
  }

  Serial.println("[Camera] Ready!");
  return true;
}

// ====================== JSON PARSING ======================

void parseResponse(const String& response) {
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, response);

  if (err) {
    Serial.print("[JSON] Parse error: ");
    Serial.println(err.c_str());
    Serial.println(response);
    return;
  }

  if (!(doc["success"] | false)) {
    Serial.printf("[Result] Server error: %s\n", doc["error"] | "Unknown");
    return;
  }

  JsonObject det       = doc["detection"];
  const char* label    = det["label"]      | "Unknown";
  const char* category = det["category"]   | "Unknown";
  int minPrice         = det["minPrice"]   | 0;
  int maxPrice         = det["maxPrice"]   | 0;
  int confidence       = det["confidence"] | 0;

  Serial.println();
  Serial.println("========== DETECTION RESULT ==========");
  Serial.printf("  Item:       %s\n", label);
  Serial.printf("  Category:   %s\n", category);
  Serial.printf("  Price:      $%d - $%d\n", minPrice, maxPrice);
  Serial.printf("  Confidence: %d%%\n", confidence);
  Serial.println("======================================");
  Serial.println();
}

// ====================== HTTP POST ======================

bool sendToServer(uint8_t* imageData, size_t imageLen) {
  String url = SERVER_URL;
  if (USE_MOCK) url += "?mock=true";

  String boundary  = "----BumpBoxESP32Boundary";
  String bodyStart = "--" + boundary + "\r\n"
                     "Content-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\n"
                     "Content-Type: image/jpeg\r\n\r\n";
  String bodyEnd   = "\r\n--" + boundary + "--\r\n";

  size_t totalLen = bodyStart.length() + imageLen + bodyEnd.length();
  Serial.printf("[HTTP] Body: %u bytes (image: %u)\n", totalLen, imageLen);

  // Allocate in PSRAM to avoid exhausting internal SRAM
  uint8_t* body = (uint8_t*)ps_malloc(totalLen);
  if (!body) {
    Serial.println("[HTTP] Memory allocation failed!");
    return false;
  }

  // Assemble: header + JPEG binary + footer
  size_t offset = 0;
  memcpy(body + offset, bodyStart.c_str(), bodyStart.length());
  offset += bodyStart.length();
  memcpy(body + offset, imageData, imageLen);
  offset += imageLen;
  memcpy(body + offset, bodyEnd.c_str(), bodyEnd.length());

  HTTPClient http;
  http.begin(url);
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);

  Serial.printf("[HTTP] POST %s\n", url.c_str());
  int code = http.POST(body, totalLen);
  free(body);

  if (code == 200) {
    String resp = http.getString();
    http.end();
    parseResponse(resp);
    return true;
  }

  if (code > 0) {
    Serial.printf("[HTTP] Server returned %d: %s\n", code, http.getString().c_str());
  } else {
    Serial.printf("[HTTP] Request failed: %s\n", http.errorToString(code).c_str());
  }
  http.end();
  return false;
}

// ====================== CAPTURE & SEND ======================

void captureAndSend() {
  Serial.println("\n---------- CAPTURE ----------");

  // Flash ON — illuminate the locker
  digitalWrite(FLASH_LED_PIN, HIGH);
  delay(FLASH_WARMUP_MS);

  // Discard stale frame (captured before flash)
  camera_fb_t* fb = esp_camera_fb_get();
  if (fb) esp_camera_fb_return(fb);

  // Capture fresh frame (with flash)
  fb = esp_camera_fb_get();
  digitalWrite(FLASH_LED_PIN, LOW);

  if (!fb) {
    Serial.println("[Camera] Capture failed!");
    blinkError(5);
    return;
  }

  Serial.printf("[Camera] %u bytes (%ux%u)\n", fb->len, fb->width, fb->height);

  if (fb->len > 1000000) {
    Serial.println("[Camera] Image exceeds 1MB server limit!");
    esp_camera_fb_return(fb);
    blinkError(4);
    return;
  }

  bool ok = sendToServer(fb->buf, fb->len);
  esp_camera_fb_return(fb);

  if (ok) {
    flashLED(2, 100);  // Success: 2 short blinks
  } else {
    blinkError(5);
  }
}

// ====================== SETUP & LOOP ======================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("========================================");
  Serial.println("  BumpBox ESP32-CAM v1.0");
  Serial.println("  Smart Locker Camera System");
  Serial.println("----------------------------------------");
  Serial.println("  Trigger: button (GPIO 13) or type 'c'");
  Serial.println("========================================");
  Serial.println();

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(FLASH_LED_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);
  digitalWrite(STATUS_LED_PIN, HIGH);  // OFF (active LOW)

  if (!initCamera()) {
    Serial.println("[FATAL] Camera init failed. Halting.");
    while (true) {
      blinkError(3);
      delay(2000);
    }
  }

  connectWiFi();
  Serial.println("[Ready] Waiting for trigger...\n");
}

void loop() {
  bool trigger = false;

  // Button check (active LOW, with debounce)
  if (digitalRead(BUTTON_PIN) == LOW && millis() - lastButtonPress > DEBOUNCE_MS) {
    lastButtonPress = millis();
    Serial.println("[Trigger] Button pressed");
    trigger = true;
  }

  // Serial command check
  if (Serial.available()) {
    char cmd = Serial.read();
    while (Serial.available()) Serial.read();  // drain buffer
    if (cmd == 'c' || cmd == 'C') {
      Serial.println("[Trigger] Serial command");
      trigger = true;
    }
  }

  if (trigger) {
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Reconnecting...");
      connectWiFi();
    }
    if (WiFi.status() == WL_CONNECTED) {
      captureAndSend();
    } else {
      Serial.println("[Error] No WiFi — cannot send image");
      blinkError(3);
    }
  }

  delay(50);
}
