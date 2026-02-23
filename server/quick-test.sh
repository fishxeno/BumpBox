#!/bin/bash

# Quick test script - simulates complete ESP32 flow

echo "========================================"
echo "  BumpBox Quick Test"
echo "========================================"
echo ""

echo "[1/4] Triggering capture..."
curl -X POST http://localhost:8080/api/locker/trigger-capture \
  -H "Content-Type: application/json" \
  -d '{"lockerId":"locker1"}' \
  2>/dev/null
echo ""
sleep 1

echo "[2/4] Checking trigger status..."
curl http://localhost:8080/api/locker/capture-trigger 2>/dev/null
echo ""
sleep 1

echo "[3/4] Simulating detection (Headphones)..."
curl -X POST http://localhost:8080/api/test/simulate-detection \
  -H "Content-Type: application/json" \
  -d '{"lockerId":"locker1","itemType":"Headphones"}' \
  2>/dev/null
echo ""
sleep 1

echo "[4/4] Fetching detection result..."
curl http://localhost:8080/api/detections/latest 2>/dev/null
echo ""
echo ""

echo "========================================"
echo "  Test Complete!"
echo "========================================"
echo ""
echo "Now open Flutter app and press 'Sell Item'"
echo "The detection should appear within 2 seconds"
echo ""
