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
  lockerId: null
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
 * Store a detection result
 */
export function storeDetection(detection, lockerId = 'locker1') {
  const timestamp = new Date().toISOString();
  latestDetection.result = detection;
  latestDetection.timestamp = timestamp;
  latestDetection.lockerId = lockerId;
  
  // Optional: Add TTL to clear old detections after 5 minutes
  setTimeout(() => {
    if (latestDetection.timestamp === timestamp) {
      latestDetection.result = null;
      latestDetection.timestamp = null;
      latestDetection.lockerId = null;
    }
  }, 5 * 60 * 1000); // 5 minutes
}

/**
 * Get latest detection result
 * Optionally filter by timestamp (return null if not newer than 'since')
 */
export function getLatestDetection(sinceTimestamp = null) {
  if (!latestDetection.result) {
    return { detection: null };
  }
  
  if (sinceTimestamp && latestDetection.timestamp) {
    const sinceDate = new Date(sinceTimestamp);
    const detectionDate = new Date(latestDetection.timestamp);
    if (detectionDate <= sinceDate) {
      return { detection: null };
    }
  }
  
  return {
    detection: latestDetection.result,
    timestamp: latestDetection.timestamp,
    lockerId: latestDetection.lockerId
  };
}
