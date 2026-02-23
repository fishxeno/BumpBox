#!/usr/bin/env node

/**
 * Test script to simulate ESP32 camera behavior without hardware
 * 
 * This script polls the backend for capture triggers and simulates
 * sending detection results, just like the real ESP32 would do.
 * 
 * Usage:
 *   node test-detection.js [itemType]
 * 
 * Examples:
 *   node test-detection.js              # Default: Headphones
 *   node test-detection.js Laptop       # Simulate laptop detection
 *   node test-detection.js Smartphone   # Simulate smartphone detection
 */

const http = require('http');

const BASE_URL = 'http://localhost:8080';
const LOCKER_ID = 'locker1';
const ITEM_TYPE = process.argv[2] || 'Headphones';
const POLL_INTERVAL = 2000; // 2 seconds

console.log('========================================');
console.log('  BumpBox ESP32 Simulator');
console.log('========================================');
console.log(`  Locker ID: ${LOCKER_ID}`);
console.log(`  Item Type: ${ITEM_TYPE}`);
console.log(`  Polling: every ${POLL_INTERVAL}ms`);
console.log('========================================\n');
console.log('Polling for capture trigger...\n');

// Poll for capture trigger
const pollInterval = setInterval(() => {
  checkTrigger();
}, POLL_INTERVAL);

function checkTrigger() {
  makeRequest('/api/locker/capture-trigger', 'GET', null, (data) => {
    if (data.shouldCapture) {
      console.log(`✅ [TRIGGER DETECTED] Locker: ${data.lockerId}`);
      console.log('📸 Simulating camera capture and detection...\n');
      
      // Simulate detection
      setTimeout(() => {
        simulateDetection();
      }, 1000);
    }
  });
}

function simulateDetection() {
  const payload = JSON.stringify({
    lockerId: LOCKER_ID,
    itemType: ITEM_TYPE
  });

  makeRequest('/api/test/simulate-detection', 'POST', payload, (data) => {
    console.log('========== DETECTION RESULT ==========');
    console.log(`  Item:       ${data.detection.label}`);
    console.log(`  Category:   ${data.detection.category}`);
    console.log(`  Price:      $${data.detection.minPrice} - $${data.detection.maxPrice}`);
    console.log(`  Confidence: ${data.detection.confidence}%`);
    console.log('======================================\n');
    console.log('✅ Detection stored. Flutter app can now retrieve it.\n');
    console.log('Continuing to poll for next trigger...\n');
  });
}

function makeRequest(path, method, body, callback) {
  const options = {
    hostname: 'localhost',
    port: 8080,
    path: path,
    method: method,
    headers: {
      'Content-Type': 'application/json'
    }
  };

  if (body) {
    options.headers['Content-Length'] = Buffer.byteLength(body);
  }

  const req = http.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      try {
        const parsed = JSON.parse(data);
        if (callback) callback(parsed);
      } catch (e) {
        // Ignore parse errors for polling
      }
    });
  });

  req.on('error', (error) => {
    // Silently handle connection errors during polling
    if (method !== 'GET') {
      console.error(`❌ Error: ${error.message}`);
    }
  });

  if (body) {
    req.write(body);
  }
  
  req.end();
}

// Handle Ctrl+C gracefully
process.on('SIGINT', () => {
  console.log('\n\n👋 Stopping ESP32 simulator...');
  clearInterval(pollInterval);
  process.exit(0);
});
