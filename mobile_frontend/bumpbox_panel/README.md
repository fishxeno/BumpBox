# bumpbox_panel

A Flutter app to be displayed on the BumpBox as a dashboard screen.

## Features

### ✅ Implemented
- **Time-Decay Pricing**: Exponential price decay over 7-day listing period
- **Attention Detection**: Physical presence tracking using ML Kit Face Detection
- **Surge Pricing**: Dynamic price increases based on attention (physical + simulated online)
- **Mock Backend**: Simulated online interest data (views, clicks, wishlist)
- **Real-time Updates**: Price automatically updates every 10 seconds
- **Data Persistence**: State saved across app restarts using SharedPreferences
- **Enhanced UI**: 
  - Shows current price breakdown (decay base + surge offset)
  - Time remaining countdown
  - Floor price indicator
  - Separate badges for physical vs online interest

## TODOs
- [x] Pricing algorithm
    - [x] Face and attention detection
    - [x] Reduce price by day (exponential decay implemented)
    - [x] Halt price reduction with attention data (surge pricing on top of decay)
    - [x] Simulated online interest (mock backend, ready for real API integration)
    - [ ] Exaggerate the pricing algorithm increase/decrease based on facial recognition
- [x] Display item details (dynamic from Item model)
- [ ] Let users pay for item on dashboard
- [ ] Testing flow
    - [ ] When user click on test, prompt for card
    - [ ] Prompt user that they will be refunded 
    - [ ] On card payment success, open locker and start 5 minute timer
    - [ ] After 5 minute timer, re-verify item condition

## Price Decay Implementation

### Algorithm
Uses exponential decay formula:
```
price = floorPrice + (startingPrice - floorPrice) * decayBase^hoursElapsed
```

- **Half-life**: 84 hours (3.5 days)
- **Listing duration**: 7 days default
- **Floor price**: Seller-set minimum (price never goes below)
- **Update interval**: 10 seconds

### Surge Pricing
- **5% compound increase** per attention event
- **Physical attention**: Face detected for 5 seconds (configurable)
- **Online interest**: Simulated (5% probability per 5-second poll)
- **Cooldown**: 5 seconds after person leaves (resets surge to 0)
- **Key behavior**: Price returns to **current decay base**, not original starting price

### Integration Points for Backend
Mock backend ready for replacement with real API:
- `MockDataService.getMockItem()` → `GET /api/items/:id`
- `MockDataService.getRealisticOnlineInterest()` → `GET /api/items/:id/online-interest`
- `MockDataService.shouldTriggerOnlineSurge()` → Backend surge decision logic
- Storage service saves state locally, can sync with backend on network restore

## Project Structure
```
lib/
├── config/
│   └── pricing_config.dart          # All pricing constants
├── models/
│   ├── attention_state.dart         # Face tracking state
│   └── item.dart                    # Item/listing model
├── screens/
│   ├── attention_monitor_screen.dart # Debug screen (existing)
│   └── kiosk_dashboard_screen.dart  # Main production UI
├── services/
│   ├── attention_detector.dart      # Face detection (existing)
│   ├── camera_service.dart          # Camera management (existing)
│   ├── mock_data_service.dart       # Simulated backend
│   ├── pricing_service.dart         # Pricing calculations
│   └── storage_service.dart         # Local persistence
└── main.dart
```

## Configuration

### Testing vs Production Thresholds
Currently using **testing values** for faster iteration:
- Physical presence threshold: **5 seconds** (PRD specifies 15s)
- Cooldown duration: **5 seconds** (PRD specifies 5 minutes)

To switch to production values, update `PricingConfig`:
```dart
static const Duration physicalPresenceThreshold = Duration(seconds: 15);
static const Duration surgeCooldownDuration = Duration(minutes: 5);
```

## Running the App

```bash
flutter pub get
flutter run
```

Long-press anywhere on the price display to access the debug screen with detailed attention tracking metrics.

