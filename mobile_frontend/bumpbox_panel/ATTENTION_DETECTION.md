# Attention Detection App

This Flutter app uses the phone's front camera and Google ML Kit Face Detection to determine if the user is currently paying attention to the phone.

## Features

- **Real-time Face Detection**: Uses Google ML Kit's face detection API
- **Eye Tracking**: Monitors if eyes are open or closed
- **Head Pose Analysis**: Checks head orientation (pitch, yaw, roll)
- **Attention Scoring**: Calculates confidence level for attention state
- **Live Camera Preview**: Shows front camera feed with attention status

## How It Works

The app processes camera frames at ~5 FPS and analyzes:

1. **Face Presence**: Detects if a face is visible
2. **Eye State**: Checks if both eyes are open (>80% probability)
3. **Head Orientation**: 
   - Pitch: -20° to 20° (not tilted too far up/down)
   - Yaw: -30° to 30° (facing the screen)
4. **Confidence Score**: Combines all metrics to determine attention level

### Attention States

- **✓ Paying Attention** (Green): Face detected, eyes open, head facing screen
- **⚠ Not Paying Attention** (Orange): Face detected but eyes closed or looking away
- **✗ No Face Detected** (Red): No face visible in camera
- **? Unknown** (Grey): Processing or waiting for data

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

1. Tap **"Start Monitoring"** to begin attention detection
2. Position your face in front of the camera
3. The app will show:
   - Live camera preview
   - Current attention status (color-coded)
   - Confidence percentage
   - Detailed metrics (eyes open, head orientation)
4. Tap **"Stop Monitoring"** to pause detection

## Architecture

```
lib/
├── models/
│   └── attention_state.dart       # Data models for attention state & metrics
├── services/
│   ├── camera_service.dart        # Camera initialization & streaming
│   └── attention_detector.dart    # ML Kit integration & processing
├── screens/
│   └── attention_monitor_screen.dart  # Main UI
└── main.dart                       # App entry point
```

## Key Components

### CameraService
Manages camera lifecycle, permissions, and image streaming.

### AttentionDetector
- Processes camera frames using ML Kit Face Detection
- Extracts face landmarks and classification data
- Calculates attention state based on multiple factors

### AttentionMonitorScreen
Provides UI with:
- Camera preview
- Real-time status display
- Start/stop controls
- Visual feedback (color-coded states)

## Performance Considerations

- Processes frames at 5 FPS (throttled for efficiency)
- Uses medium resolution camera preview (640x480)
- Runs face detection asynchronously
- Skips processing if previous frame still processing

## Permissions

### iOS (Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to detect if you're paying attention</string>
```

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

## Future Enhancements

- [ ] Add gaze estimation for more precise eye tracking
- [ ] Implement attention duration tracking
- [ ] Add notifications when attention is lost
- [ ] Support multiple face tracking
- [ ] Export attention logs/analytics
- [ ] Calibration mode for personalized thresholds
- [ ] Dark mode support

## Troubleshooting

**Camera not initializing:**
- Ensure camera permission is granted in device settings
- Try restarting the app
- Check if another app is using the camera

**Poor detection accuracy:**
- Ensure good lighting conditions
- Position face 30-60cm from camera
- Face the camera directly
- Remove glasses/obstacles if they affect detection

**App crashes on startup:**
- Run `flutter clean && flutter pub get`
- Ensure device supports ML Kit (most modern phones do)

## Dependencies

- `camera: ^0.11.0` - Camera access
- `google_mlkit_face_detection: ^0.11.0` - Face detection & landmarks
- `permission_handler: ^11.3.1` - Runtime permission handling

## License

This project is part of the BumpBox mobile frontend.
