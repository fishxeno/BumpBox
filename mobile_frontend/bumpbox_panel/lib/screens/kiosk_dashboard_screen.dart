import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../config/pricing_config.dart';
import '../models/attention_state.dart';
import '../models/item.dart';
import '../services/attention_detector.dart';
import '../services/camera_service.dart';
import '../services/item_api_service.dart';
import '../services/mock_data_service.dart';
import '../services/pricing_service.dart';
import '../services/storage_service.dart';
import 'attention_monitor_screen.dart';
import 'payment_dialog.dart';
import 'sell_screen.dart';

class KioskDashboardScreen extends StatefulWidget {
  const KioskDashboardScreen({super.key});

  @override
  State<KioskDashboardScreen> createState() => _KioskDashboardScreenState();
}

class _KioskDashboardScreenState extends State<KioskDashboardScreen>
    with WidgetsBindingObserver {
  // Services
  final CameraService _cameraService = CameraService();
  late final PersonTracker _personTracker;

  // Item data (nullable - may be empty when locker has no item)
  Item? _currentItem;
  LockerState _lockerState = LockerState.empty;

  // State variables
  PresenceState? _currentState;
  bool _isLoading = true;
  String? _error;
  int _surgeCount = 0; // Count of surge events (physical + online)
  int _physicalSurgeCount = 0; // Count of physical attention events
  int _onlineSurgeCount = 0; // Count of online interest events
  double _currentDecayPrice = 0.0; // Current time-decay base price
  double _currentPrice = 0.0; // Final displayed price (decay + surge)
  OnlineInterest? _lastOnlineInterest;

  // Timers for real-time updates
  Timer? _priceDecayTimer;
  Timer? _onlineInterestTimer;
  Timer? _statusPollTimer;

  // Test mode state
  DateTime? _testStartTime;
  Timer? _testCountdownTimer;
  Duration? _testTimeRemaining;

  // Testing: Time offset for fast-forwarding
  int _daysFastForwarded = 0;
  bool _debugMode = false; // Toggle to show/hide debug buttons

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load saved state or create new item
    _loadOrCreateItem();

    // Initialize person tracker with callbacks
    _personTracker = PersonTracker(
      onPriceIncrease: (trackingId) {
        _incrementPrice(isPhysical: true);
        debugPrint(
          '💰 Physical attention surge! Count: $_surgeCount (P:$_physicalSurgeCount, O:$_onlineSurgeCount), New Price: \$${_currentPrice.toStringAsFixed(2)}',
        );
      },
      onCooldownComplete: () {
        setState(() {
          // Reset surge counts but keep decay price continuing
          _surgeCount = 0;
          _physicalSurgeCount = 0;
          _onlineSurgeCount = 0;
          _updatePrices();
          _saveSurgeCounts(); // Persist updated counts
        });
        debugPrint(
          '✅ Cooldown completed, price reset to decay base: \$${_currentDecayPrice.toStringAsFixed(2)}',
        );
      },
    );

    // Start real-time price decay updates
    _startPriceDecayTimer();

    // Start online interest monitoring
    _startOnlineInterestPolling();

    _initializeCamera();
    // Hides phone default status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _priceDecayTimer?.cancel();
    _onlineInterestTimer?.cancel();
    _statusPollTimer?.cancel();
    _testCountdownTimer?.cancel();
    _cameraService.dispose();
    _personTracker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraService.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraService.isInitialized) {
        _startMonitoring();
      }
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await _cameraService.initialize();
      if (!success) {
        setState(() {
          _error = 'Unable to access camera. Please check permissions.';
          _isLoading = false;
        });
        return;
      }

      await _startMonitoring();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'System error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startMonitoring() async {
    if (!_cameraService.isInitialized) {
      return;
    }

    try {
      await _cameraService.startImageStream((CameraImage image) async {
        final state = await _personTracker.processImage(image);

        if (mounted) {
          setState(() {
            _currentState = state;
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Monitoring error: $e';
      });
    }
  }

  /// Get effective current time (with testing offset)
  DateTime _getEffectiveNow() {
    return DateTime.now().add(Duration(days: _daysFastForwarded));
  }

  /// Update both decay price and final price
  void _updatePrices() {
    if (_currentItem == null) return;

    final now = _getEffectiveNow();
    _currentDecayPrice = PricingService.calculateTimeDecayPrice(
      _currentItem!,
      now,
    );
    _currentPrice = PricingService.getFinalPrice(
      _currentItem!,
      _surgeCount,
      now,
    );
    StorageService.saveLastPriceUpdate(now); // Persist update time
  }

  /// Fast forward time for testing (adds 1 day)
  void _fastForwardOneDay() {
    setState(() {
      _daysFastForwarded++;
      _updatePrices();
    });
    debugPrint('⏩ Fast forwarded to +$_daysFastForwarded days');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏩ Fast forwarded to +$_daysFastForwarded days'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  /// Load item and surge counts from storage, API, or create new from mock
  Future<void> _loadOrCreateItem() async {
    // Try to load saved item
    final savedItem = await StorageService.loadItem();
    final savedCounts = await StorageService.loadSurgeCounts();

    // Load test session if exists
    final testStartTime = await StorageService.loadTestStartTime();
    if (testStartTime != null) {
      setState(() {
        _testStartTime = testStartTime;
      });
      _startTestCountdown();
      debugPrint('🧪 Resumed test session from $testStartTime');
    }

    if (savedItem != null) {
      // Check if saved item is sold
      if (savedItem.isSold == true) {
        debugPrint('💾 Saved item was sold, transitioning to empty state');
        await _transitionToEmptyState();
        return;
      }

      _currentItem = savedItem;
      _lockerState = LockerState.available;
      _surgeCount = savedCounts['surgeCount'] ?? 0;
      _physicalSurgeCount = savedCounts['physicalSurgeCount'] ?? 0;
      _onlineSurgeCount = savedCounts['onlineSurgeCount'] ?? 0;
      debugPrint('💾 Loaded saved item: ${_currentItem!.name}');
    } else {
      // No saved state, try to fetch from backend API
      debugPrint('📡 Fetching item from backend API...');
      final apiItem = await ItemApiService.fetchLatestItem();

      if (apiItem != null) {
        // Check if the fetched item is sold
        if (apiItem.isSold == true) {
          debugPrint('📡 API returned sold item, transitioning to empty state');
          await _transitionToEmptyState();
          return;
        }

        _currentItem = apiItem;
        _lockerState = LockerState.available;
        await StorageService.saveItem(_currentItem!);
        debugPrint('✅ Loaded item from API: ${_currentItem!.name}');
      } else {
        // API failed or no item, fall back to mock data
        debugPrint('⚠️ API fetch failed, using mock data');
        _currentItem = MockDataService.getMockItem();
        _lockerState = LockerState.available;
        await StorageService.saveItem(_currentItem!);
        debugPrint('🆕 Created new mock item: ${_currentItem!.name}');
      }
    }

    _updatePrices();

    // Start polling for sold status if we have an item
    if (_lockerState == LockerState.available) {
      _startStatusPolling();
    }
  }

  /// Manually refresh item from backend API
  ///
  /// This method fetches the latest item from the backend and updates
  /// the display. Useful for testing or when a new item is listed.
  Future<void> _refreshItemFromAPI() async {
    debugPrint('🔄 Manually refreshing item from API...');

    final apiItem = await ItemApiService.fetchLatestItem();

    if (apiItem != null) {
      // Check if the item is sold
      if (apiItem.isSold == true) {
        debugPrint('🔄 Refreshed item is sold, transitioning to empty state');
        await _transitionToEmptyState();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Item sold! Locker is now empty'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      setState(() {
        _currentItem = apiItem;
        _lockerState = LockerState.available;
        // Reset surge counts for new item
        _surgeCount = 0;
        _physicalSurgeCount = 0;
        _onlineSurgeCount = 0;
      });

      await StorageService.saveItem(_currentItem!);
      await _saveSurgeCounts();
      _updatePrices();

      // Restart polling for new item
      _startStatusPolling();

      debugPrint('✅ Refreshed item from API: ${_currentItem!.name}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Loaded: ${_currentItem!.name}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      debugPrint('❌ Failed to refresh item from API');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to load item from backend'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start polling for item sold status
  void _startStatusPolling() {
    // Stop any existing timer
    _stopStatusPolling();

    debugPrint(
      '🔄 Starting status polling every ${ApiConfig.statusPollIntervalSeconds}s',
    );

    _statusPollTimer = Timer.periodic(
      Duration(seconds: ApiConfig.statusPollIntervalSeconds),
      (timer) async {
        if (mounted &&
            _lockerState == LockerState.available &&
            _currentItem != null) {
          final apiItem = await ItemApiService.fetchLatestItem();

          if (apiItem != null && apiItem.isSold == true) {
            debugPrint(
              '🔔 Polling detected item sold! Transitioning to empty state',
            );
            await _transitionToEmptyState();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Item sold! Locker is now empty'),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      },
    );
  }

  /// Stop polling for item sold status
  void _stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    debugPrint('🛑 Stopped status polling');
  }

  /// Transition to empty locker state
  Future<void> _transitionToEmptyState() async {
    setState(() {
      _currentItem = null;
      _lockerState = LockerState.empty;
      _surgeCount = 0;
      _physicalSurgeCount = 0;
      _onlineSurgeCount = 0;
      _currentDecayPrice = 0.0;
      _currentPrice = 0.0;
    });

    // Clear stored item data
    await StorageService.clearCurrentItem();

    // Stop polling when empty
    _stopStatusPolling();

    debugPrint('🏁 Transitioned to empty locker state');
  }

  /// Save surge counts to storage
  Future<void> _saveSurgeCounts() async {
    await StorageService.saveSurgeCounts(
      surgeCount: _surgeCount,
      physicalSurgeCount: _physicalSurgeCount,
      onlineSurgeCount: _onlineSurgeCount,
    );
  }

  /// Start timer to update decay price periodically
  void _startPriceDecayTimer() {
    _priceDecayTimer = Timer.periodic(PricingConfig.decayUpdateInterval, (
      timer,
    ) {
      if (mounted) {
        setState(() {
          _updatePrices();
        });
      }
    });
  }

  /// Start timer to poll for simulated online interest
  void _startOnlineInterestPolling() {
    _onlineInterestTimer = Timer.periodic(
      PricingConfig.onlineInterestPollInterval,
      (timer) {
        if (mounted) {
          _checkOnlineInterest();
        }
      },
    );
  }

  /// Check for online interest and trigger surge if needed
  void _checkOnlineInterest() {
    final interest = MockDataService.getRealisticOnlineInterest();
    setState(() {
      _lastOnlineInterest = interest;
    });

    // Trigger surge if mock backend detects high interest
    if (MockDataService.shouldTriggerOnlineSurge()) {
      _incrementPrice(isPhysical: false);
      debugPrint(
        '🌐 Online interest surge! Views: ${interest.pageViews}, Clicks: ${interest.clickCount}',
      );
    }
  }

  /// Increment price due to attention (physical or online)
  void _incrementPrice({required bool isPhysical}) {
    setState(() {
      _surgeCount++;
      if (isPhysical) {
        _physicalSurgeCount++;
      } else {
        _onlineSurgeCount++;
      }
      _updatePrices();
      _saveSurgeCounts(); // Persist updated counts
    });
  }

  Color _getPriceColor() {
    if (_currentItem == null) return Colors.grey.shade700;

    if (_surgeCount == 0) {
      // No surge, show decay-based color
      final progress = _currentItem!.getListingProgress(_getEffectiveNow());
      if (progress < 0.3) {
        return Colors.blue.shade700; // Early days, still expensive
      } else if (progress < 0.7) {
        return Colors.green.shade700; // Mid-way, good deal
      } else {
        return Colors.purple.shade700; // Late deal, very cheap
      }
    } else if (_surgeCount <= 2) {
      return Colors.orange.shade700; // Moderate surge
    } else {
      return Colors.red.shade700; // High surge
    }
  }

  /// Get surge badge color based on source
  Color _getSurgeBadgeColor() {
    if (_physicalSurgeCount > 0 && _onlineSurgeCount > 0) {
      return Colors.purple.shade600; // Both sources
    } else if (_physicalSurgeCount > 0) {
      return Colors.green.shade600; // Physical only
    } else {
      return Colors.blue.shade600; // Online only
    }
  }

  /// Get surge badge icon
  IconData _getSurgeBadgeIcon() {
    if (_physicalSurgeCount > 0 && _onlineSurgeCount > 0) {
      return Icons.people; // Both
    } else if (_physicalSurgeCount > 0) {
      return Icons.person; // Physical
    } else {
      return Icons.cloud; // Online
    }
  }

  String _getAvailabilityText() {
    if (_currentState == null) {
      return 'Checking availability...';
    }

    switch (_currentState!.status) {
      case PresenceStatus.idle:
        return 'Available Now';
      case PresenceStatus.tracking:
        return 'Available Now';
      case PresenceStatus.priceIncreased:
        return 'High Demand';
      case PresenceStatus.cooldown:
        return 'Available Soon';
    }
  }

  Color _getAvailabilityColor() {
    if (_currentState == null) {
      return Colors.grey.shade600;
    }

    switch (_currentState!.status) {
      case PresenceStatus.idle:
      case PresenceStatus.tracking:
        return Colors.green.shade600;
      case PresenceStatus.priceIncreased:
        return Colors.orange.shade600;
      case PresenceStatus.cooldown:
        return Colors.blue.shade600;
    }
  }

  void _navigateToDebugScreen() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttentionMonitorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sell Item Button (primary action)
          // FloatingActionButton.extended(
          // onPressed: () async {
          //   final result = await Navigator.push(
          //     context,
          //     MaterialPageRoute(builder: (context) => const SellScreen()),
          //   );

          //   // Automatically refresh if item was successfully listed
          //   if (result == true && mounted) {
          //     await _refreshItemFromAPI();
          //   }
          // },
          //   icon: const Icon(Icons.add_shopping_cart),
          //   label: const Text('Sell Item'),
          //   backgroundColor: Colors.green.shade600,
          //   foregroundColor: Colors.white,
          //   tooltip: 'Sell a new item',
          //   heroTag: 'sell_button',
          // ),
          // Debug buttons (only visible when debug mode is enabled)
          if (_debugMode) ...[
            const SizedBox(height: 16),
            // Fast Forward Button (testing)
            FloatingActionButton.extended(
              onPressed: _fastForwardOneDay,
              icon: const Icon(Icons.fast_forward),
              label: Text(
                _daysFastForwarded > 0 ? '+$_daysFastForwarded d' : 'FF',
              ),
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              tooltip: 'Fast Forward 1 Day (Testing)',
              heroTag: 'fastforward_button',
            ),
            const SizedBox(height: 16),
            // Refresh Item Button (fetch latest from backend)
            FloatingActionButton.extended(
              onPressed: _refreshItemFromAPI,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              tooltip: 'Refresh item from backend',
              heroTag: 'refresh_button',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Initializing...',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 24),
              Text(
                'Service Temporarily Unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;

          // Show empty state if no item
          if (_lockerState == LockerState.empty || _currentItem == null) {
            return _buildEmptyState(isLandscape);
          }

          if (isLandscape) {
            return _buildLandscapeLayout();
          } else {
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }

  /// Build empty locker state UI
  Widget _buildEmptyState(bool isLandscape) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isLandscape ? 48.0 : 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Empty box icon
              Container(
                width: isLandscape ? 180 : 150,
                height: isLandscape ? 180 : 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300, width: 3),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: isLandscape ? 100 : 80,
                  color: Colors.grey.shade400,
                ),
              ),
              SizedBox(height: isLandscape ? 40 : 32),

              // Main message
              Text(
                'Locker is Empty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isLandscape ? 42 : 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: isLandscape ? 20 : 16),

              // Subtitle / call to action
              Text(
                'No items currently listed for sale',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isLandscape ? 20 : 18,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: isLandscape ? 16 : 12),
              Text(
                'Want to sell something? List your item now!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isLandscape ? 18 : 16,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: isLandscape ? 48 : 40),

              // Prominent "List an Item" button
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SellScreen()),
                  );

                  // If item was successfully created, refresh
                  if (result == true) {
                    await _refreshItemFromAPI();
                  }
                },
                icon: const Icon(Icons.add_shopping_cart, size: 32),
                label: Text(
                  'List an Item for Sale',
                  style: TextStyle(
                    fontSize: isLandscape ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 48 : 40,
                    vertical: isLandscape ? 24 : 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
              SizedBox(height: isLandscape ? 24 : 20),

              // Secondary refresh button
              TextButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _refreshItemFromAPI();
                },
                icon: Icon(Icons.refresh, color: Colors.grey.shade600),
                label: Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: isLandscape ? 18 : 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          // Availability Status Bar - Full Width
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: _getAvailabilityColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getAvailabilityColor(), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 20, color: _getAvailabilityColor()),
                const SizedBox(width: 12),
                Text(
                  _getAvailabilityText(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _getAvailabilityColor(),
                  ),
                ),
              ],
            ),
          ),

          // Main Content - Two Column Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Side - Item Information
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FittedBox(
                                child: Text(
                                  _currentItem!.name,
                                  style: TextStyle(
                                    fontSize: 6,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade900,
                                    letterSpacing: -1.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentItem!.description,
                              style: TextStyle(
                                fontSize: 28,
                                color: Colors.grey.shade700,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Time remaining indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentItem!.formatTimeRemaining(
                                      _getEffectiveNow(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_surgeCount > 0) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getSurgeBadgeIcon(),
                                color: _getSurgeBadgeColor(),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'High demand pricing',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_lastOnlineInterest != null)
                                    Text(
                                      'Online: ${_lastOnlineInterest!.pageViews} views, ${_lastOnlineInterest!.clickCount} clicks',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 48),

                // Right Side - Price Display
                Expanded(
                  child: GestureDetector(
                    onLongPress: _navigateToDebugScreen,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current Price',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                              color: _getPriceColor(),
                            ),
                            child: Text(
                              PricingConfig.formatPrice(_currentPrice),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Price breakdown (debug mode only)
                          if (_debugMode)
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Decay base:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      PricingConfig.formatPrice(
                                        _currentDecayPrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_surgeCount > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _getSurgeBadgeIcon(),
                                            size: 16,
                                            color: _getSurgeBadgeColor(),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Surge:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: _getSurgeBadgeColor(),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '+${PricingConfig.formatPrice(_currentPrice - _currentDecayPrice)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: _getSurgeBadgeColor(),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Divider(color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Floor price:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    Text(
                                      PricingConfig.formatPrice(
                                        _currentItem!.floorPrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Availability Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _getAvailabilityColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _getAvailabilityColor(), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 16, color: _getAvailabilityColor()),
                  const SizedBox(width: 8),
                  Text(
                    _getAvailabilityText(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _getAvailabilityColor(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Item Name (Long press to toggle debug mode)
            GestureDetector(
              onLongPress: () {
                setState(() {
                  _debugMode = !_debugMode;
                });
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _debugMode
                          ? '🛠️ Debug mode enabled'
                          : '✅ Debug mode disabled',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: _debugMode
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                );
              },
              child: Text(
                _currentItem!.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Item Description
            Text(
              _currentItem!.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            // Time remaining
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _currentItem!.formatTimeRemaining(_getEffectiveNow()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Price Display
            Expanded(
              child: Center(
                child: GestureDetector(
                  onLongPress: _navigateToDebugScreen,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Current Price',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: _getPriceColor(),
                            letterSpacing: -2,
                          ),
                          child: Text(PricingConfig.formatPrice(_currentPrice)),
                        ),
                        // Price details (debug mode only)
                        if (_debugMode) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Decay: ${PricingConfig.formatPrice(_currentDecayPrice)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_surgeCount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getSurgeBadgeIcon(),
                                  size: 13,
                                  color: _getSurgeBadgeColor(),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Surge: +${PricingConfig.formatPrice(_currentPrice - _currentDecayPrice)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _getSurgeBadgeColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Floor: ${PricingConfig.formatPrice(_currentItem!.floorPrice)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Additional info during price increase
            if (_surgeCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSurgeBadgeIcon(),
                      color: _getSurgeBadgeColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'High demand pricing',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Return Button (shown only during active test session)
            if (_testTimeRemaining != null && _testStartTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
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
                          Icon(
                            Icons.timer,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
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
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
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
                                    content: Text(
                                      '\u2705 Item returned successfully! Full refund processed.',
                                    ),
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
                                    content: Text(
                                      '\u274c Failed to return item. Please try again.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted && Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }

                            debugPrint('\u274c Error during return: $e');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('\u274c Error: $e'),
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

            // Action Buttons
            const SizedBox(height: 24),
            Row(
              children: [
                // Buy Button (Primary Action)
                Expanded(
                  child: ElevatedButton.icon(
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
                                    'Preparing payment...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      try {
                        // Update price to backend and get new payment link
                        debugPrint(
                          '🛒 Buy button pressed, syncing price \$${_currentPrice.toStringAsFixed(2)}...',
                        );
                        final updatedItem =
                            await ItemApiService.updateItemPrice(_currentPrice);

                        // Close loading indicator
                        if (mounted) {
                          Navigator.of(context).pop();
                        }

                        if (updatedItem == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ Failed to prepare payment'),
                                duration: Duration(seconds: 3),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        // Check if payment link exists
                        if (updatedItem.paymentLink == null ||
                            updatedItem.paymentLink!.isEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ Payment link not available'),
                                duration: Duration(seconds: 3),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        // Update local state with new payment link
                        setState(() {
                          _currentItem = updatedItem;
                        });
                        await StorageService.saveItem(_currentItem!);

                        debugPrint(
                          '✅ Price synced: \$${_currentPrice.toStringAsFixed(2)}, showing payment dialog',
                        );

                        // Show payment dialog with updated item
                        if (!mounted) return;
                        final paymentSuccessful = await showPaymentDialog(
                          context,
                          item: updatedItem,
                          currentPrice: _currentPrice,
                        );

                        // Refresh item if payment was successful
                        if (paymentSuccessful && mounted) {
                          debugPrint(
                            '✅ Payment successful, refreshing item...',
                          );
                          await _refreshItemFromAPI();
                        }
                      } catch (e) {
                        // Close loading indicator if still open
                        if (mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }

                        debugPrint('❌ Error preparing payment: $e');

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Error: $e'),
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.shopping_cart, size: 20),
                    label: const Text('Buy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4169E1), // Royal blue
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Test Button (Secondary Action)
                Expanded(
                  child: OutlinedButton.icon(
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
                          '\ud83e\uddea Test button pressed, syncing price \$${_currentPrice.toStringAsFixed(2)}...',
                        );
                        final updatedItem =
                            await ItemApiService.updateItemPrice(_currentPrice);

                        // Close loading indicator
                        if (mounted) {
                          Navigator.of(context).pop();
                        }

                        if (updatedItem == null ||
                            updatedItem.paymentLink == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '\u274c Failed to prepare test session',
                                ),
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

                        debugPrint(
                          '\u2705 Test session prepared, showing payment dialog',
                        );

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
                          debugPrint(
                            '\u2705 Test payment successful, starting 5-minute timer',
                          );

                          // Store test session start time
                          setState(() {
                            _testStartTime = DateTime.now();
                          });
                          await StorageService.saveTestStartTime(
                            _testStartTime!,
                          );

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

                        debugPrint('\u274c Error preparing test session: $e');

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('\u274c Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.timer, size: 20),
                    label: const Text(
                      'Test 5 min',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Sell Item Button (Tertiary Action - Debug Mode Only)
                if (_debugMode) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SellScreen(),
                          ),
                        );

                        // Automatically refresh if item was successfully listed
                        if (result == true && mounted) {
                          await _refreshItemFromAPI();
                        }
                      },
                      icon: const Icon(Icons.sell, size: 20),
                      label: const Text('Sell'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

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
}
