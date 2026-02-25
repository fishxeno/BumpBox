# Test 5-Minute Feature - Frontend-Focused Plan

**Purpose**: Add a "Test 5 min" button that allows customers to try items with a refundable deposit. User pays full price (demo mode - no real Stripe charges), locker opens, and they have 5 minutes to return for a full refund.

## Overview

This plan prioritizes frontend implementation with **minimal backend changes**. Since this is a demo, we skip actual Stripe payment cancellation and focus on UI/UX flow and state management.

### Key Decisions
- **Frontend-heavy approach**: Most logic lives in Flutter UI
- **Demo mode**: No real Stripe refunds - `/api/return` just resets database state
- **Minimal backend**: Small fix to existing endpoint + optional test mode tracking
- **Reuse existing components**: Extend payment dialog instead of creating new one
- **Live countdown timer**: Shows remaining time in Return button
- **Main dashboard Return button**: More visible than keeping dialog open

---

## Implementation Steps

### Backend (Minimal Changes)

#### 1. Fix Existing `/api/return` Endpoint
**File**: `server/server.js` lines 103-116

**Current Issues**:
- Missing `await` on database calls (race condition)
- Missing `async` function declaration

**Changes Needed**:
```javascript
// Change to async and add await to database calls
app.get("/api/return", async (req, res) => {
    try {
        cancelCapture();
        const [rows] = await db.execute(`SELECT itemid FROM items ORDER BY itemid DESC LIMIT 1`);
        const itemid = rows[0].itemid;
        const query = `UPDATE items SET sale_status = 0 WHERE itemid = ?`;
        await db.execute(query, [itemid]);
        
        // Optional: Lock locker via MQTT
        // mqttClient.publish("esp32/door1/alayerofsecurity/lock", JSON.stringify({ action: "lock" }));
        
        res.status(200).json({ message: "item returned", status: false });
    } catch (error) {
        console.error('return-item Error:', error.message);
        return res.status(500).json({ error: 'Failed to return item' });
    }
});
```

**Why**: Prevents database state mismatch. Already has `cancelCapture()` to prevent payment capture.

---

#### 2. Optional: Add Test Mode Tracking (Backend)
**File**: `server/server.js` line 328-356 (PUT /api/item/price endpoint)

**Optional Addition**:
- Accept `isTestMode` boolean in request body
- Store in database (requires adding `isTestMode` column to items table)
- Return test mode flag in response

**Database Migration** (if tracking test mode):
```sql
ALTER TABLE items ADD COLUMN isTestMode BOOLEAN DEFAULT FALSE;
ALTER TABLE items ADD COLUMN testStartTime DATETIME NULL;
```

**Backend Update** (optional):
```javascript
// In PUT /api/item/price endpoint, accept optional isTestMode parameter
const { price, isTestMode = false } = req.body;

// When updating item price:
const query = `UPDATE items SET price = ?, isTestMode = ?, testStartTime = ? WHERE itemid = ?`;
await db.execute(query, [price, isTestMode, isTestMode ? new Date() : null, itemid]);
```

**Note**: This is **optional for demo**. Frontend can track test state locally without backend support.

---

### Frontend (Primary Focus)

#### 3. Add Return API Method
**File**: `mobile_frontend/bumpbox_panel/lib/services/item_api_service.dart`

**Add new method**:
```dart
/// Call the return endpoint to cancel a test purchase
/// Returns true if return was successful, false otherwise
static Future<bool> returnItem() async {
  try {
    print('[ItemApiService] Calling return endpoint');
    
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/return'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      print('[ItemApiService] Item returned successfully');
      return true;
    } else {
      print('[ItemApiService] Return failed: ${response.statusCode} ${response.body}');
      return false;
    }
  } catch (e) {
    print('[ItemApiService] Error returning item: $e');
    return false;
  }
}
```

**Why**: Encapsulates API call logic in service layer.

---

#### 4. Update Payment Dialog for Test Mode
**File**: `mobile_frontend/bumpbox_panel/lib/screens/payment_dialog.dart`

**Changes**:
1. Add optional `isTestMode` parameter to `showPaymentDialog()` function
2. Update dialog title and add info text when in test mode
3. Pass test mode flag through to dialog state

**Function signature update**:
```dart
Future<bool> showPaymentDialog(
  BuildContext context, {
  required Item item,
  required double currentPrice,
  bool isTestMode = false, // NEW PARAMETER
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PaymentDialog(
      item: item,
      currentPrice: currentPrice,
      isTestMode: isTestMode, // PASS THROUGH
    ),
  );

  return result ?? false;
}
```

**Dialog widget update**:
```dart
class _PaymentDialog extends StatefulWidget {
  final Item item;
  final double currentPrice;
  final bool isTestMode; // NEW FIELD

  const _PaymentDialog({
    required this.item,
    required this.currentPrice,
    this.isTestMode = false, // NEW PARAMETER
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}
```

**UI changes in dialog**:
- Change title: `isTestMode ? "Test Purchase - Refundable Deposit" : "Complete Your Purchase"`
- Add info banner for test mode:
```dart
if (widget.isTestMode)
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange.shade800),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'You have 5 minutes to return this item for a full refund',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  ),
```

**Why**: Clear distinction between Buy and Test modes without code duplication.

---

#### 5. Implement "Test 5 min" Button Handler
**File**: `mobile_frontend/bumpbox_panel/lib/screens/kiosk_dashboard_screen.dart`

**Location**: Lines 1508-1525 (replace empty `onPressed` handler)

**Implementation**:
```dart
OutlinedButton.icon(
  onPressed: () async {
    HapticFeedback.mediumImpact();

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Preparing test session...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Update price to backend (same as Buy button)
      debugPrint(
        '🧪 Test button pressed, syncing price \$${_currentPrice.toStringAsFixed(2)}...',
      );
      final updatedItem = await ItemApiService.updateItemPrice(
        _currentPrice,
      );

      // Close loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (updatedItem == null || updatedItem.paymentLink == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to prepare test session'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update local state
      setState(() {
        _currentItem = updatedItem;
      });
      await StorageService.saveItem(_currentItem!);

      debugPrint('✅ Test session prepared, showing payment dialog');

      // Show payment dialog in TEST MODE
      if (!mounted) return;
      final paymentSuccessful = await showPaymentDialog(
        context,
        item: updatedItem,
        currentPrice: _currentPrice,
        isTestMode: true, // THIS IS THE KEY DIFFERENCE
      );

      // If payment successful, start test session
      if (paymentSuccessful && mounted) {
        debugPrint('✅ Test payment successful, starting 5-minute timer');
        
        // Store test session start time
        setState(() {
          _testStartTime = DateTime.now();
        });
        await StorageService.saveTestStartTime(_testStartTime!);
        
        // Start countdown timer
        _startTestCountdown();
        
        // Refresh item state
        await _refreshItemFromAPI();
      }
    } catch (e) {
      // Close loading indicator if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      debugPrint('❌ Error preparing test session: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  },
  icon: const Icon(Icons.timer, size: 20),
  label: const Text('Test 5 min', overflow: TextOverflow.ellipsis),
  style: OutlinedButton.styleFrom(
    foregroundColor: Colors.grey.shade800,
    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),
```

**Why**: Reuses Buy flow but passes `isTestMode: true` to payment dialog.

---

#### 6. Add Test Session State Variables
**File**: `mobile_frontend/bumpbox_panel/lib/screens/kiosk_dashboard_screen.dart`

**Add to State class** (near line 50):
```dart
// Test mode state
DateTime? _testStartTime;
Timer? _testCountdownTimer;
Duration? _testTimeRemaining;
```

**Why**: Tracks active test sessions and remaining time.

---

#### 7. Implement Countdown Timer Logic
**File**: `mobile_frontend/bumpbox_panel/lib/screens/kiosk_dashboard_screen.dart`

**Add methods to State class**:
```dart
/// Start the 5-minute test countdown timer
void _startTestCountdown() {
  // Cancel existing timer if any
  _testCountdownTimer?.cancel();
  
  debugPrint('🕐 Starting 5-minute test countdown');
  
  _testCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_testStartTime == null) {
      timer.cancel();
      return;
    }
    
    final elapsed = DateTime.now().difference(_testStartTime!);
    final remaining = const Duration(minutes: 5) - elapsed;
    
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      // Time expired
      debugPrint('⏰ Test period expired');
      setState(() {
        _testTimeRemaining = null;
        _testStartTime = null;
      });
      timer.cancel();
      
      // Refresh item state (should show as sold now)
      _refreshItemFromAPI();
      
      // Clear saved test time
      StorageService.clearTestStartTime();
    } else {
      // Update remaining time
      setState(() {
        _testTimeRemaining = remaining;
      });
    }
  });
}

/// Stop and clear the test countdown timer
void _stopTestCountdown() {
  _testCountdownTimer?.cancel();
  _testCountdownTimer = null;
  setState(() {
    _testTimeRemaining = null;
    _testStartTime = null;
  });
  StorageService.clearTestStartTime();
}

/// Format duration as MM:SS
String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}
```

**Update dispose method** to include:
```dart
@override
void dispose() {
  _testCountdownTimer?.cancel(); // ADD THIS LINE
  _priceDecayTimer?.cancel();
  _onlineInterestTimer?.cancel();
  _statusPollTimer?.cancel();
  // ... rest of dispose
}
```

**Why**: Provides live countdown with automatic cleanup.

---

#### 8. Add Return Button UI Component
**File**: `mobile_frontend/bumpbox_panel/lib/screens/kiosk_dashboard_screen.dart`

**Add before Buy/Test buttons** (around line 1370):
```dart
// Return Button (shown only during active test session)
if (_testTimeRemaining != null && _testStartTime != null)
  Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Test Period: ${_formatDuration(_testTimeRemaining!)} remaining',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Return Item?'),
                  content: const Text(
                    'Are you sure you want to return this item? You will receive a full refund.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Return Item'),
                    ),
                  ],
                ),
              );
              
              if (confirmed != true || !mounted) return;
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing return...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              
              try {
                // Call return API
                final success = await ItemApiService.returnItem();
                
                // Close loading dialog
                if (mounted) {
                  Navigator.of(context).pop();
                }
                
                if (success) {
                  // Stop countdown timer
                  _stopTestCountdown();
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Item returned successfully! Full refund processed.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  
                  // Refresh item state
                  await _refreshItemFromAPI();
                } else {
                  // Show error
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Failed to return item. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                
                debugPrint('❌ Error during return: $e');
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.keyboard_return),
            label: const Text('Return Item for Full Refund'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
```

**Why**: Visible countdown with clear return action. Only shows during active test period.

---

#### 9. Add Storage Service Methods
**File**: `mobile_frontend/bumpbox_panel/lib/services/storage_service.dart`

**Add methods for test session persistence**:
```dart
static const String _testStartTimeKey = 'test_start_time';

/// Save test session start time
static Future<void> saveTestStartTime(DateTime startTime) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_testStartTimeKey, startTime.toIso8601String());
    print('[StorageService] Test start time saved: $startTime');
  } catch (e) {
    print('[StorageService] Error saving test start time: $e');
  }
}

/// Load test session start time
static Future<DateTime?> loadTestStartTime() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_testStartTimeKey);
    if (timeStr == null) return null;
    
    final startTime = DateTime.parse(timeStr);
    print('[StorageService] Test start time loaded: $startTime');
    
    // Check if expired (more than 5 minutes ago)
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed > const Duration(minutes: 5)) {
      print('[StorageService] Test period expired, clearing');
      await clearTestStartTime();
      return null;
    }
    
    return startTime;
  } catch (e) {
    print('[StorageService] Error loading test start time: $e');
    return null;
  }
}

/// Clear test session start time
static Future<void> clearTestStartTime() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_testStartTimeKey);
    print('[StorageService] Test start time cleared');
  } catch (e) {
    print('[StorageService] Error clearing test start time: $e');
  }
}
```

**Why**: Persists test state across app restarts.

---

#### 10. Load Test State on App Start
**File**: `mobile_frontend/bumpbox_panel/lib/screens/kiosk_dashboard_screen.dart`

**Update `_loadOrCreateItem()` method** to load test state:
```dart
Future<void> _loadOrCreateItem() async {
  // ... existing loading logic ...
  
  // Load test session if exists
  final testStartTime = await StorageService.loadTestStartTime();
  if (testStartTime != null) {
    setState(() {
      _testStartTime = testStartTime;
    });
    _startTestCountdown();
    debugPrint('🧪 Resumed test session from ${testStartTime}');
  }
  
  // ... rest of method ...
}
```

**Why**: Resumes countdown timer after app restart.

---

## Verification Checklist

### Test Mode Flow
- [ ] Click "Test 5 min" button → payment dialog opens with orange test mode banner
- [ ] Payment dialog title shows "Test Purchase - Refundable Deposit"
- [ ] Info text: "You have 5 minutes to return this item for a full refund"
- [ ] After payment → Return button appears with countdown timer
- [ ] Timer shows format: "04:59", "04:58", etc.
- [ ] Database check: `sale_status = 1` for item

### Return Flow
- [ ] Within 5 minutes: Return button is visible
- [ ] Click Return button → confirmation dialog appears
- [ ] Confirm return → shows "Processing return..." loading
- [ ] Return succeeds → success snackbar, Return button disappears
- [ ] Database check: `sale_status = 0`
- [ ] Timer stops and is cleared

### Timeout Flow
- [ ] Start test session, wait >5 minutes
- [ ] Return button automatically disappears when timer hits 00:00
- [ ] Backend captures payment via `scheduleCapture()` timeout
- [ ] Database check: `sale_status = 2` (fully sold)

### Edge Cases
- [ ] Try returning after timer expires → Return button not visible
- [ ] App restart during test period → countdown resumes from correct time
- [ ] Try clicking Return multiple times quickly → only processes once
- [ ] Close payment dialog without paying → test session doesn't start
- [ ] Network error on return → shows error snackbar, timer continues

### UI/UX
- [ ] Return button stands out with orange color and border
- [ ] Countdown timer updates every second
- [ ] Button UI is responsive and doesn't overflow
- [ ] Loading states show appropriate messages
- [ ] Success/error messages are clear

---

## Summary of Changes

### Backend (2 small fixes)
1. **server.js** - Make `/api/return` async and add awaits (lines 103-116)
2. **Optional** - Track test mode in database (if needed)

### Frontend (Main implementation)
1. **item_api_service.dart** - Add `returnItem()` method
2. **payment_dialog.dart** - Add `isTestMode` parameter and conditional UI
3. **kiosk_dashboard_screen.dart** - Implement Test button handler, Return button UI, countdown logic
4. **storage_service.dart** - Add test session persistence methods

### Implementation Time Estimate
- Backend fixes: **15 minutes**
- Frontend implementation: **2-3 hours**
- Testing and refinement: **1 hour**
- **Total: ~3-4 hours**

---

## Key Benefits of This Approach

1. **Minimal Backend Changes**: Only fixes existing bug, no new database schema required (if we skip test mode tracking)
2. **Reuses Code**: Payment dialog extended rather than duplicated
3. **Demo-Ready**: No real Stripe integration needed for returns
4. **Good UX**: Live countdown timer provides clear feedback
5. **Persistent**: Test sessions survive app restarts
6. **Safe**: Confirmation dialog prevents accidental returns
