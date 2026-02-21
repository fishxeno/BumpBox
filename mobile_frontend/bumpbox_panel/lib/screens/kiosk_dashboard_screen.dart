import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/pricing_config.dart';
import '../models/attention_state.dart';
import '../models/item.dart';
import '../services/attention_detector.dart';
import '../services/camera_service.dart';
import '../services/mock_data_service.dart';
import '../services/pricing_service.dart';
import '../services/storage_service.dart';
import 'attention_monitor_screen.dart';

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

  // Item data (from mock service, simulating backend)
  late Item _currentItem;

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

  // Testing: Time offset for fast-forwarding
  int _daysFastForwarded = 0;

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
    final now = _getEffectiveNow();
    _currentDecayPrice = PricingService.calculateTimeDecayPrice(
      _currentItem,
      now,
    );
    _currentPrice = PricingService.getFinalPrice(
      _currentItem,
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

  /// Load item and surge counts from storage, or create new from mock
  Future<void> _loadOrCreateItem() async {
    // Try to load saved item
    final savedItem = await StorageService.loadItem();
    final savedCounts = await StorageService.loadSurgeCounts();

    if (savedItem != null) {
      _currentItem = savedItem;
      _surgeCount = savedCounts['surgeCount'] ?? 0;
      _physicalSurgeCount = savedCounts['physicalSurgeCount'] ?? 0;
      _onlineSurgeCount = savedCounts['onlineSurgeCount'] ?? 0;
      debugPrint('💾 Loaded saved item: ${_currentItem.name}');
    } else {
      // No saved state, create new from mock
      _currentItem = MockDataService.getMockItem();
      await StorageService.saveItem(_currentItem);
      debugPrint('🆕 Created new mock item: ${_currentItem.name}');
    }

    _updatePrices();
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
    if (_surgeCount == 0) {
      // No surge, show decay-based color
      final progress = _currentItem.getListingProgress(_getEffectiveNow());
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fastForwardOneDay,
        icon: const Icon(Icons.fast_forward),
        label: Text(_daysFastForwarded > 0 ? '+$_daysFastForwarded d' : 'FF'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        tooltip: 'Fast Forward 1 Day (Testing)',
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

          if (isLandscape) {
            return _buildLandscapeLayout();
          } else {
            return _buildPortraitLayout();
          }
        },
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
                                  _currentItem.name,
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
                              _currentItem.description,
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
                                    _currentItem.formatTimeRemaining(
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
                          // Price breakdown
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
                                      _currentItem.floorPrice,
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

            // Item Name
            Text(
              _currentItem.name,
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

            const SizedBox(height: 16),

            // Item Description
            Text(
              _currentItem.description,
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
                    _currentItem.formatTimeRemaining(_getEffectiveNow()),
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
                        const SizedBox(height: 12),
                        // Price details
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
                          'Floor: ${PricingConfig.formatPrice(_currentItem.floorPrice)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
