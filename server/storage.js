/**
 * In-memory storage for ESP32 camera integration
 * Used to coordinate between Flutter app, backend, and ESP32 camera
 */

// Capture trigger state (set by Flutter, read by ESP32)
export const captureTrigger = {
  triggered: false,
  lockerId: null,
  triggeredAt: null
};

// Latest detection result (set by detectObject route, read by Flutter)
export const latestDetection = {
  result: null,
  timestamp: null,
  lockerId: null,
  imageBuffer: null
};

/**
 * Set capture trigger for ESP32
 */
export function setCaptureTrigger(lockerId) {
  captureTrigger.triggered = true;
  captureTrigger.lockerId = lockerId;
  captureTrigger.triggeredAt = new Date().toISOString();
}

/**
 * Get and reset capture trigger (called by ESP32)
 * Returns the trigger state and resets it (one-time trigger)
 */
export function getAndResetCaptureTrigger() {
  const shouldCapture = captureTrigger.triggered;
  const lockerId = captureTrigger.lockerId || 'locker1';

  if (captureTrigger.triggered) {
    captureTrigger.triggered = false;
  }
  
  return { shouldCapture, lockerId };
}

/**
 * Store a detection result with optional image buffer
 */
export function storeDetection(detection, lockerId = 'locker1', imageBuffer = null) {
  const timestamp = new Date().toISOString();
  latestDetection.result = detection;
  latestDetection.timestamp = timestamp;
  latestDetection.lockerId = lockerId;
  latestDetection.imageBuffer = imageBuffer;
  console.log(`[storage] Detection stored at ${timestamp} for ${lockerId}: ${detection.label}`);
  
  // Optional: Add TTL to clear old detections after 5 minutes
  setTimeout(() => {
    if (latestDetection.timestamp === timestamp) {
      latestDetection.result = null;
      latestDetection.timestamp = null;
      latestDetection.lockerId = null;
      latestDetection.imageBuffer = null;
    }
  }, 5 * 60 * 1000); // 5 minutes
}

/**
 * Get latest detection result
 * Optionally filter by timestamp (return null if not newer than 'since')
 */
export function getLatestDetection(sinceTimestamp = null) {
  console.log(`[storage] getLatestDetection called with since=${sinceTimestamp}`);
  console.log(`[storage] Current detection: timestamp=${latestDetection.timestamp}, label=${latestDetection.result?.label}`);
  
  if (!latestDetection.result) {
    console.log(`[storage] No detection stored, returning null`);
    return { detection: null };
  }
  
  if (sinceTimestamp && latestDetection.timestamp) {
    const sinceDate = new Date(sinceTimestamp);
    const detectionDate = new Date(latestDetection.timestamp);
    console.log(`[storage] Comparing: detection ${detectionDate.toISOString()} vs since ${sinceDate.toISOString()}`);
    if (detectionDate <= sinceDate) {
      console.log(`[storage] Detection too old, returning null`);
      return { detection: null };
    }
  }
  
  return {
    detection: latestDetection.result,
    timestamp: latestDetection.timestamp,
    lockerId: latestDetection.lockerId,
    hasImage: latestDetection.imageBuffer !== null
  };
}
