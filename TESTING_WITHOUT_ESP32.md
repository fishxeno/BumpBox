# Testing Without ESP32 Camera

This guide shows how to test the complete sell flow without ESP32 camera hardware.

## Quick Start (Automated)

### 1. Start Backend Server
```bash
cd server
npm start
```

### 2. Run ESP32 Simulator
In a new terminal:
```bash
cd server
node test-detection.js
```

Available item types:
- `node test-detection.js Headphones` (default)
- `node test-detection.js Laptop`
- `node test-detection.js Smartphone`
- `node test-detection.js Book`
- `node test-detection.js Watch`

### 3. Run Flutter App
In a new terminal:
```bash
cd mobile_frontend/bumpbox_panel
flutter run
```

### 4. Test the Flow
1. In Flutter app, press **"Sell Item"** button
2. Press **"Start Detection"**
3. Watch the simulator terminal - it will detect the trigger and send a simulated detection
4. Flutter app displays the detected item
5. Fill in the form and press **"List Item"**

---

## Manual Testing (Step by Step)

### Test Backend Endpoints Individually

```bash
# 1. Trigger capture (simulates Flutter app)
curl -X POST http://localhost:8080/api/locker/trigger-capture \
  -H "Content-Type: application/json" \
  -d '{"lockerId":"locker1"}'

# Expected response:
# {"success":true,"message":"Capture triggered","lockerId":"locker1"}

# 2. Check trigger status (simulates ESP32 polling)
curl http://localhost:8080/api/locker/capture-trigger

# Expected response (first call):
# {"shouldCapture":true,"lockerId":"locker1"}
# Expected response (second call):
# {"shouldCapture":false,"lockerId":"locker1"}

# 3. Simulate detection (replaces ESP32 capture)
curl -X POST http://localhost:8080/api/test/simulate-detection \
  -H "Content-Type: application/json" \
  -d '{"lockerId":"locker1","itemType":"Laptop"}'

# Expected response:
# {
#   "success": true,
#   "message": "Simulated detection stored",
#   "detection": {
#     "label": "Laptop",
#     "category": "Electronics",
#     "minPrice": 150,
#     "maxPrice": 600,
#     "confidence": 92
#   }
# }

# 4. Fetch detection (simulates Flutter polling)
curl http://localhost:8080/api/detections/latest

# Expected response:
# {
#   "detection": {
#     "label": "Laptop",
#     "category": "Electronics",
#     "minPrice": 150,
#     "maxPrice": 600,
#     "confidence": 92
#   },
#   "timestamp": "2026-02-22T10:30:00.000Z",
#   "lockerId": "locker1"
# }

# 5. Test item creation
curl -X POST http://localhost:8080/api/item \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+6581234567",
    "item_name": "Used Laptop",
    "description": "MacBook Pro 2021, excellent condition",
    "price": 500,
    "days": 7
  }'
```

---

## Testing Scenarios

### Scenario 1: Happy Path
1. Start backend and simulator
2. Start Flutter app
3. Press "Sell Item" → "Start Detection"
4. Simulator detects trigger and sends detection
5. Flutter displays results within 2-4 seconds
6. Fill form and create listing
7. Success dialog with payment link

### Scenario 2: Detection Timeout
1. Start backend (NO simulator)
2. Start Flutter app
3. Press "Sell Item" → "Start Detection"
4. Wait 30 seconds
5. Flutter shows timeout error
6. User can retry

### Scenario 3: Multiple Item Types
```bash
# Terminal 1: Simulator for Headphones
node test-detection.js Headphones

# Terminal 2: Simulator for Laptop
node test-detection.js Laptop

# Terminal 3: Simulator for Smartphone
node test-detection.js Smartphone
```
Test with different items to see different price ranges.

### Scenario 4: Rapid Triggers
```bash
# Send multiple triggers quickly
for i in {1..5}; do
  curl -X POST http://localhost:8080/api/locker/trigger-capture \
    -H "Content-Type: application/json" \
    -d '{"lockerId":"locker1"}'
  sleep 1
done
```
Verify simulator only processes each trigger once.

---

## Troubleshooting

### Backend not responding
```bash
# Check if server is running
curl http://localhost:8080/api/locker/capture-trigger

# If connection refused:
cd server
npm start
```

### Simulator not detecting triggers
```bash
# Check if trigger is set
curl http://localhost:8080/api/locker/capture-trigger

# Manually send detection
curl -X POST http://localhost:8080/api/test/simulate-detection \
  -H "Content-Type: application/json" \
  -d '{"itemType":"Headphones"}'
```

### Flutter app not showing detection
```bash
# Check if detection is stored
curl http://localhost:8080/api/detections/latest

# If null, manually store one
curl -X POST http://localhost:8080/api/test/simulate-detection \
  -H "Content-Type: application/json" \
  -d '{"itemType":"Laptop"}'
```

### Detection expired (5 min TTL)
```bash
# Send a fresh detection
curl -X POST http://localhost:8080/api/test/simulate-detection \
  -H "Content-Type: application/json" \
  -d '{"itemType":"Smartphone"}'
```

---

## Testing with Python (Alternative)

If you prefer Python:

```python
#!/usr/bin/env python3
import requests
import time

BASE_URL = "http://localhost:8080"

# Poll for trigger
while True:
    response = requests.get(f"{BASE_URL}/api/locker/capture-trigger")
    data = response.json()
    
    if data.get("shouldCapture"):
        print(f"✅ Trigger detected!")
        
        # Simulate detection
        detection = requests.post(
            f"{BASE_URL}/api/test/simulate-detection",
            json={"lockerId": "locker1", "itemType": "Laptop"}
        )
        print(f"📸 Detection sent: {detection.json()}")
    
    time.sleep(2)
```

---

## Verifying Database

After creating an item:

```bash
# Connect to MySQL
mysql -u root -p

# Check items table
USE bumpbox;
SELECT * FROM items ORDER BY itemid DESC LIMIT 1;
```

---

## Next Steps

Once testing without hardware is complete:
1. Flash the updated Arduino sketch to real ESP32-CAM
2. Update WiFi credentials in `.ino` file
3. Change `USE_MOCK = false` for real Vision API
4. Replace simulator with real ESP32 polling
