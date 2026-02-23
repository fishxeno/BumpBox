# BumpBox ESP32-CAM Setup Guide

Camera module for the BumpBox smart locker. Captures a photo of the item inside the locker, sends it to the backend for object detection, and prints the result (item name, category, price range) to Serial Monitor.

## Hardware Required

- **AI-Thinker ESP32-CAM** (with OV2640 camera)
- **ESP32-CAM-MB base board** (micro-USB programmer — no FTDI adapter needed)
- **Push button** (momentary, normally open) — optional, can use Serial command instead
- **2x jumper wires** (for button wiring)

### Wiring

```
Button:  GPIO 13 ---[BUTTON]--- GND
```

No external pull-up resistor needed — the code uses the ESP32's internal pull-up.

Plug the ESP32-CAM into the MB base board, then connect via micro-USB to your computer.

## Software Setup (PlatformIO)

### 1. Install PlatformIO

Install the **PlatformIO IDE** extension in VS Code (search "PlatformIO IDE" in Extensions marketplace).

### 2. Build

Open a terminal in VS Code and run:

```bash
cd esp32/bumpbox_camera
pio run
```

First time takes ~2 minutes (downloads ESP32 toolchain + ArduinoJson automatically).
Wait for `SUCCESS`.

### 3. Upload

```bash
pio run --target upload
```

If COM port not found, check Device Manager for CH340 port, or unplug/replug USB.

### 4. Serial Monitor

```bash
pio device monitor
```

Press the **RST** button on the ESP32-CAM-MB board. Baud rate is 115200 (configured in `platformio.ini`).

## Configuration

Open `src/main.cpp` and edit these lines at the top:

```cpp
const char* WIFI_SSID     = "YOUR_WIFI_SSID";       // Your WiFi network name
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";    // Your WiFi password
const bool  USE_MOCK      = true;                    // true = test mode, false = real detection
```

**Mock mode** (`USE_MOCK = true`): The server returns a fake detection result without calling Google Vision API. Use this for testing the hardware connection.

## Usage

Two ways to trigger a capture:

- **Button:** Press the push button connected to GPIO 13
- **Serial:** Type `c` in the Serial Monitor and press Enter

The result prints to Serial Monitor:

```
---------- CAPTURE ----------
[Camera] 42387 bytes (640x480)
[HTTP] Body: 42583 bytes (image: 42387)
[HTTP] POST http://bumpbox-env-1.eba-43hmmxwt.ap-southeast-1.elasticbeanstalk.com/detect-object?mock=true

========== DETECTION RESULT ==========
  Item:       Headphones
  Category:   Electronics
  Price:      $10 - $80
  Confidence: 95%
======================================
```

## Troubleshooting

### Camera init failed (0x20003 or similar)
- **Cause:** Usually a power issue
- **Fix:** Make sure you're using the 5V USB connection. Try a different USB cable. Adding a 10uF capacitor between 5V and GND can help with power stability.

### WiFi connection timed out
- **Cause:** Wrong credentials or 5GHz network
- **Fix:** ESP32 only supports **2.4GHz WiFi**. Double-check your SSID and password. Make sure your router has a 2.4GHz band enabled.

### "brownout detector was triggered"
- **Cause:** Power supply can't handle current spikes during WiFi radio use
- **Fix:** Use a quality USB cable and port. Add a 10uF capacitor between 5V and GND.

### Upload fails / COM port not found
- **Cause:** Missing CH340G driver
- **Fix:** Download and install the CH340G driver for your OS. On Windows, it usually auto-installs. On macOS, you may need to download from the manufacturer.

### HTTP POST failed
- **Cause:** Server unreachable or network issue
- **Fix:** Verify the server URL is correct. Test the endpoint from your computer first:
  ```bash
  curl -X POST "http://bumpbox-env-1.eba-43hmmxwt.ap-southeast-1.elasticbeanstalk.com/detect-object?mock=true" -F "image=@any_photo.jpg"
  ```
