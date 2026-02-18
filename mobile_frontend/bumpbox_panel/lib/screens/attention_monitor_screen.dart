import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/attention_state.dart';
import '../services/attention_detector.dart';
import '../services/camera_service.dart';

class AttentionMonitorScreen extends StatefulWidget {
  const AttentionMonitorScreen({super.key});

  @override
  State<AttentionMonitorScreen> createState() => _AttentionMonitorScreenState();
}

class _AttentionMonitorScreenState extends State<AttentionMonitorScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  late final PersonTracker _personTracker;

  PresenceState? _currentState;
  bool _isLoading = true;
  String? _error;
  bool _isMonitoring = false;
  int _priceIncreaseCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _personTracker = PersonTracker(
      onPriceIncrease: (trackingId) {
        setState(() {
          _priceIncreaseCount++;
        });
        debugPrint('💰 Price increased! Total increases: $_priceIncreaseCount');
        // TODO: Implement actual price increase logic here
      },
      onCooldownComplete: () {
        debugPrint('✅ Cooldown completed, ready for next customer');
        // TODO: Implement cooldown completion logic here (e.g., reset price, notify backend)
      },
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopMonitoring();
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
      _stopMonitoring();
    } else if (state == AppLifecycleState.resumed) {
      if (_isMonitoring) {
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
          _error =
              'Failed to initialize camera. Please grant camera permission.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startMonitoring() async {
    if (!_cameraService.isInitialized) {
      return;
    }

    setState(() {
      _isMonitoring = true;
    });

    try {
      await _cameraService.startImageStream((CameraImage image) async {
        if (!_isMonitoring) return;

        final state = await _personTracker.processImage(image);

        // Update UI with current state
        if (mounted) {
          setState(() {
            _currentState = state;
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error starting monitoring: $e';
        _isMonitoring = false;
      });
    }
  }

  Future<void> _stopMonitoring() async {
    setState(() {
      _isMonitoring = false;
    });
    await _cameraService.stopImageStream();
    _personTracker.reset();
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  Color _getStatusColor() {
    if (_currentState == null) return Colors.grey;

    switch (_currentState!.status) {
      case PresenceStatus.idle:
        return Colors.grey;
      case PresenceStatus.tracking:
        return Colors.blue;
      case PresenceStatus.priceIncreased:
        return Colors.orange;
      case PresenceStatus.cooldown:
        return Colors.purple;
    }
  }

  String _getStatusText() {
    if (_currentState == null) return 'No data';

    switch (_currentState!.status) {
      case PresenceStatus.idle:
        return '⏳ Waiting for Customer';
      case PresenceStatus.tracking:
        final seconds = _currentState!.presenceDuration.inSeconds;
        return '👤 Customer Detected: ${seconds}s';
      case PresenceStatus.priceIncreased:
        return '💰 Price Increased!';
      case PresenceStatus.cooldown:
        final remaining = _currentState!.remainingCooldown;
        if (remaining != null) {
          final minutes = remaining.inMinutes;
          final seconds = remaining.inSeconds % 60;
          return '⏰ Cooldown: ${minutes}m ${seconds}s';
        }
        return '⏰ Cooldown Active';
    }
  }

  IconData _getStatusIcon() {
    if (_currentState == null) return Icons.help_outline;

    switch (_currentState!.status) {
      case PresenceStatus.idle:
        return Icons.person_search;
      case PresenceStatus.tracking:
        return Icons.person;
      case PresenceStatus.priceIncreased:
        return Icons.attach_money;
      case PresenceStatus.cooldown:
        return Icons.timer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Camera Preview
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.black,
            child: Center(
              child:
                  _cameraService.controller != null &&
                      _cameraService.controller!.value.isInitialized
                  ? CameraPreview(_cameraService.controller!)
                  : const Text(
                      'Camera not available',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ),

        // Status Display
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: _getStatusColor().withOpacity(0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Icon(
                    _getStatusIcon(),
                    size: 64,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),

                if (_currentState != null) ...[
                  if (_currentState!.trackingId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${_currentState!.trackingId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                  if (_currentState!.details != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentState!.details!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_currentState!.status == PresenceStatus.tracking) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _currentState!.presenceDuration.inSeconds / 15.0,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),

        // Control Button
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
