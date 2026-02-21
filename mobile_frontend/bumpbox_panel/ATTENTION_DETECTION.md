# Person Presence Tracker for Smart Locker

This Flutter app uses the phone's front camera and Google ML Kit Face Detection to track person presence for a smart locker with surge pricing. When the same person stands in front of the camera for more than 15 seconds, it triggers a price increase. After the person leaves, a 5-minute cooldown prevents repeated increases for the same person.

## Features

- **Real-time Face Tracking**: Uses Google ML Kit's face tracking API to identify same person
- **15-Second Threshold**: Monitors continuous presence duration
- **Price Surge Trigger**: Automatically increases price after threshold
- **3-Second Grace Period**: Prevents false departure detection from temporary tracking loss
- **5-Minute Cooldown**: Prevents repeated increases after person leaves
- **Live Camera Preview**: Shows front camera feed with tracking status
- **Visual Progress**: Progress bar showing time until price increase

## How It Works

The app processes camera frames at ~5 FPS and uses ML Kit's tracking IDs to identify individuals:

1. **First Person Detection**: When monitoring starts, the first detected face becomes the reference
2. **Continuous Tracking**: ML Kit assigns a tracking ID to track the same person across frames
3. **Duration Monitoring**: Accumulates presence time while tracking ID remains consistent
4. **Price Increase**: After 15 seconds of continuous presence, triggers price increase (once per person)
5. **Person Departure Detection**: When face is no longer detected, waits 3 seconds to confirm departure
6. **Cooldown Start**: After confirmed departure (3s grace period), starts 5-minute cooldown
7. **Cooldown Period**: Ignores all faces for 5 minutes to prevent re-triggering
8. **Reset**: After cooldown expires, system resets and waits for next customer

**Grace Period**: The 3-second grace period prevents false cooldown triggers due to temporary face detection losses (head movements, brief occlusions, or momentary tracking failures).

### Tracking States

- **⏳ Idle** (Grey): Waiting for customer, no face detected
- **👤 Tracking** (Blue): Customer detected and being monitored (shows elapsed time)
- **💰 Price Increased** (Orange): 15s threshold reached, price has been increased
- **⏰ Cooldown** (Purple): Person left, 5-minute cooldown active (shows remaining time)

## Technical Details

### Face Tracking vs Face Recognition

**Important**: This app uses **face tracking**, not face recognition:
- ✅ Can track the *same person continuously* while they remain in frame
- ✅ Uses ML Kit's `trackingId` to identify consistency across frames
- ❌ Cannot recognize a specific individual (no identity storage)
- ❌ Tracking ID resets if person leaves frame and returns

For this use case (locker surge pricing), continuous tracking is sufficient since:
- Customers typically remain in front of the locker while deciding
- 15-second threshold applies to continuous presence only
- 5-minute cooldown handles brief departures

### Limitations

- **Session-based tracking only**: Tracking IDs don't persist across app restarts
- **Requires continuous presence**: If person leaves frame briefly, may get new tracking ID
- **Single person optimization**: Designed for one customer at a time
- **Lighting dependent**: Poor lighting can cause tracking loss

## Running the App

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- iOS device/simulator or Android device/emulator
- Camera permissions enabled

### Installation

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run on your device:
   ```bash
   flutter run
   ```

### First Time Setup

On first launch, the app will request camera permission. You must grant this permission for the app to function.

## Usage

1. Tap **"Start Monitoring"** to begin presence tracking
2. When a customer approaches, the system will:
   - Detect their face and start tracking
   - Show tracking duration with progress bar
   - Trigger price increase at 15 seconds
   - Display "Price Increased!" status
3. When customer leaves:
   - System enters 5-minute cooldown
   - Shows countdown timer
4. After cooldown expires, system resets automatically
5. Tap **"Stop Monitoring"** to pause the system

**Note**: The app counter shows total price increases during the session.

## Architecture

```
lib/
├── models/
│   └── attention_state.dart       # PresenceState and PresenceStatus enums
├── services/
│   ├── camera_service.dart        # Camera initialization & streaming
│   └── attention_detector.dart    # PersonTracker class with ML Kit
├── screens/
│   └── attention_monitor_screen.dart  # Main UI (Smart Locker Monitor)
└── main.dart                       # App entry point
```

## Key Components

### CameraService
Manages camera lifecycle, permissions, and image streaming at 5 FPS.

### PersonTracker (formerly AttentionDetector)
- Processes camera frames using ML Kit Face Detection
- Tracks person presence using face tracking IDs
- Manages state machine: idle → tracking → priceIncreased → cooldown → idle
- Triggers `onPriceIncrease` callback when threshold crossed
- Handles 15-second presence threshold and 5-minute cooldown

### AttentionMonitorScreen
Provides UI with:
- Camera preview
- Real-time tracking status display
- Progress bar for 15-second countdown
- Cooldown timer
- Total price increase counter
- Start/stop controls
- Visual feedback with color-coded states

## State Machine

```
┌─────────┐
│  IDLE   │ ← No face detected, waiting for customer
└────┬────┘
     │ Face detected
     ↓
┌─────────┐
│TRACKING │ ← Monitoring presence duration (0-15s)
└────┬────┘
     │ 15s elapsed
     ↓
┌──────────────┐
│PRICE INCREASED│ ← Price increased, person still present
└────┬─────────┘
     │ Face lost (3s grace period)
     ↓
┌─────────┐
│COOLDOWN │ ← 5-minute timer, ignores all faces
└────┬────┘
     │ 5min elapsed
     └──────→ Back to IDLE

Note: If face reappears during 3s grace period, 
returns to PRICE INCREASED state (no cooldown)
```

## Performance Considerations

- Processes frames at 5 FPS (throttled for efficiency)
- Uses medium resolution camera preview (640x480)
- Runs face detection asynchronously
- Skips processing if previous frame still processing
- Minimal ML Kit features enabled (tracking only, no landmarks/classification)

## Permissions

### iOS (Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to track customer presence for surge pricing</string>
```

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

## Integration with Pricing System

The `PersonTracker` class provides an `onPriceIncrease` callback:

```dart
PersonTracker(
  onPriceIncrease: (trackingId) {
    // TODO: Implement your price increase logic here
    // Example:
    // - Update price in database
    // - Send API request to backend
    // - Update display on locker screen
    // - Log transaction with trackingId
    debugPrint('💰 Price increased for customer: $trackingId');
  },
)
```

### Implementation Checklist

- [ ] Connect callback to backend API for price updates
- [ ] Store tracking ID in transaction logs
- [ ] Update locker display to show new price
- [ ] Add analytics/metrics tracking
- [ ] Implement error handling for API failures
- [ ] Add notification system for operators

## Future Enhancements

- [ ] Support multiple faces (track multiple customers simultaneously)
- [ ] Add manual reset button for operators
- [ ] Configurable thresholds (15s, 5min) via settings
- [ ] Local logging of all price increase events
- [ ] Remote monitoring dashboard
- [ ] Advanced analytics (peak hours, avg presence time, etc.)
- [ ] Face embeddings for true person recognition across sessions
- [ ] Integration with payment system
- [ ] Emergency override controls

## Troubleshooting

**Camera not initializing:**
- Ensure camera permission is granted in device settings
- Try restarting the app
- Check if another app is using the camera

**Tracking not working:**
- Ensure good lighting conditions
- Position customer 30-60cm from camera
- Check if face is fully visible (not partially occluded)
- Verify ML Kit is properly initialized

**Price increases multiple times for same person:**
- This shouldn't happen - check cooldown logic
- Verify person hasn't left and returned after cooldown expired
- Check logs for tracking ID changes (may indicate tracking loss)

**Tracking lost too easily:**
- Improve lighting conditions
- Reduce camera movement/vibration
- Ensure customer remains relatively still
- Consider lowering resolution if processing is too slow

**App crashes on startup:**
- Run `flutter clean && flutter pub get`
- Ensure device supports ML Kit (most modern phones do)
- Check Android/iOS minimum version requirements

## Testing Scenarios

1. **Basic Flow**: Person stands → 15s passes → price increases → person leaves → cooldown works
2. **Early Departure**: Person leaves before 15s → no price increase → new person starts fresh
3. **Prolonged Presence**: Person stays 60s → price increases only once
4. **Cooldown Test**: Person returns within 5min → no new price increase
5. **Post-Cooldown**: Person returns after 5min → new tracking cycle begins
6. **Different Person**: Person A leaves, Person B arrives during cooldown → B tracked after cooldown
7. **Tracking Loss**: Simulate poor lighting to test tracking ID stability

## Dependencies

- `camera: ^0.11.3` - Camera access and streaming
- `google_mlkit_face_detection: ^0.13.2` - Face detection with tracking
- `permission_handler: ^12.0.1` - Runtime permission handling

## License

This project is part of the BumpBox mobile frontend.

---

## Change Log

### Version 2.0 (February 2026)
- **Breaking Change**: Converted from attention detection to person presence tracking
- Added 15-second threshold for price increase triggers
- Implemented 5-minute cooldown mechanism  
- Replaced attention metrics (eyes, head pose) with simple presence tracking
- Added progress bar and countdown timers to UI
- Renamed classes: `AttentionDetector` → `PersonTracker`, `AttentionState` → `PresenceState`
- Optimized ML Kit config (removed unused landmark/classification features)

### Version 1.0 (Original)
- Initial attention detection implementation
- Eye tracking and head pose analysis
