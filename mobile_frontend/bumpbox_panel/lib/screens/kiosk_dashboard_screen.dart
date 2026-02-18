import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/attention_state.dart';
import '../services/attention_detector.dart';
import '../services/camera_service.dart';
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

  // Hardcoded item data
  static const String _itemName = 'Bose Headphones';
  static const String _itemDescription =
      'Occasionally used headphones for home leisure use';
  static const double _basePrice = 100.0;

  // State variables
  PresenceState? _currentState;
  bool _isLoading = true;
  String? _error;
  int _priceIncreaseCount = 0;
  double _currentPrice = _basePrice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _personTracker = PersonTracker(
      onPriceIncrease: (trackingId) {
        setState(() {
          _priceIncreaseCount++;
          _currentPrice = _calculatePrice();
        });
        debugPrint(
          '💰 Price increased! Count: $_priceIncreaseCount, New Price: \$${_currentPrice.toStringAsFixed(2)}',
        );
      },
      onCooldownComplete: () {
        setState(() {
          _priceIncreaseCount = 0;
          _currentPrice = _basePrice;
        });
        debugPrint(
          '✅ Cooldown completed, price reset to \$${_basePrice.toStringAsFixed(2)}',
        );
      },
    );
    _initializeCamera();
    // Hides phone default status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  double _calculatePrice() {
    // 5% compound increase per price increase event
    return _basePrice * pow(1.05, _priceIncreaseCount);
  }

  Color _getPriceColor() {
    if (_priceIncreaseCount == 0) {
      return Colors.green.shade700;
    } else if (_priceIncreaseCount <= 2) {
      return Colors.orange.shade700;
    } else {
      return Colors.red.shade700;
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
    return Scaffold(backgroundColor: Colors.grey.shade100, body: _buildBody());
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
                      Text(
                        _itemName,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _itemDescription,
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      if (_priceIncreaseCount > 0) ...[
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
                                Icons.trending_up,
                                color: Colors.orange.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'High demand pricing in effect',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
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
                            'Current Rate',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getPriceColor(),
                            ),
                            child: Expanded(
                              child: FittedBox(
                                child: Text(
                                  '\$${_currentPrice.toStringAsFixed(2)}',
                                ),
                              ),
                            ),
                          ),
                          if (_priceIncreaseCount > 0) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Base: \$${_basePrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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

            const SizedBox(height: 48),

            // Item Name
            Text(
              _itemName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 24),

            // Item Description
            Text(
              _itemDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 64),

            // Price Display
            Flexible(
              child: GestureDetector(
                onLongPress: _navigateToDebugScreen,
                child: Container(
                  padding: const EdgeInsets.all(32),
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
                        'Daily Rate',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: _getPriceColor(),
                          letterSpacing: -2,
                        ),
                        child: Text('\$${_currentPrice.toStringAsFixed(2)}'),
                      ),
                      if (_priceIncreaseCount > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Base: \$${_basePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Additional info during price increase
            if (_priceIncreaseCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
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
                      Icons.trending_up,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'High demand pricing in effect',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
