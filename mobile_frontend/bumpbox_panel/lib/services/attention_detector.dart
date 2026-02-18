import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/attention_state.dart';

class PersonTracker {
  final FaceDetector _faceDetector;
  bool _isProcessing = false;
  DateTime? _lastProcessTime;

  // Tracking state
  int? _referenceTrackingId;
  DateTime? _trackingStartTime;
  DateTime? _triggeredAt;
  DateTime? _cooldownStartTime; // When cooldown began
  DateTime? _cooldownPausedAt; // When cooldown was paused by face detection
  Duration _cooldownAccumulatedTime =
      Duration.zero; // Actual cooldown time accumulated
  DateTime? _lastFaceSeenTime;
  int? _cooldownTrackingId; // Store tracking ID during cooldown
  bool _priceIncreased = false; // Current person triggered price increase
  bool _anyPriceIncreaseOccurred =
      false; // Any person triggered increase (for cooldown)

  // Constants
  static const _processingInterval = Duration(milliseconds: 200);
  static const _presenceThreshold = Duration(seconds: 5);
  static const _cooldownDuration = Duration(seconds: 5);
  static const _absenceGracePeriod = Duration(
    seconds: 3,
  ); // Grace period before cooldown

  // Callback for price increase event
  final void Function(int trackingId)? onPriceIncrease;
  // Callback for cooldown completion
  final void Function()? onCooldownComplete;

  PersonTracker({this.onPriceIncrease, this.onCooldownComplete})
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableTracking: true, // Essential for tracking same person
          enableLandmarks: false,
          enableClassification: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

  Future<PresenceState> processImage(CameraImage image) async {
    // Throttle processing
    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _processingInterval) {
      return _getCurrentState(details: 'Throttled');
    }

    if (_isProcessing) {
      return _getCurrentState(details: 'Processing');
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      // Check if cooldown has completed
      if (_cooldownStartTime != null) {
        final cooldownRemaining = _getCooldownRemaining();
        if (cooldownRemaining != null && cooldownRemaining <= Duration.zero) {
          _resetTracking();
          if (onCooldownComplete != null) {
            onCooldownComplete!();
          }
        }
      }

      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        return _getCurrentState(details: 'Failed to convert image');
      }

      final faces = await _faceDetector.processImage(inputImage);

      // Handle no face detected
      if (faces.isEmpty) {
        return _handleNoFace();
      }

      // Use the first detected face
      final face = faces.first;
      final trackingId = face.trackingId;

      if (trackingId == null) {
        return _getCurrentState(details: 'No tracking ID');
      }

      return _handleFaceDetected(trackingId, now);
    } catch (e) {
      debugPrint('Error processing image: $e');
      return _getCurrentState(details: 'Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  PresenceState _handleNoFace() {
    final now = DateTime.now();

    // Check if we're in cooldown period - accumulate cooldown time since no face present
    if (_cooldownStartTime != null) {
      // If cooldown was paused, resume it
      if (_cooldownPausedAt != null) {
        // Resume cooldown - set new start time to now
        _cooldownStartTime = now;
        _cooldownPausedAt = null;
        debugPrint(
          'Cooldown resumed. Previously accumulated: ${_cooldownAccumulatedTime.inSeconds}s',
        );
      }

      // Calculate remaining cooldown
      final remaining = _getCooldownRemaining();

      if (remaining != null && remaining > Duration.zero) {
        return PresenceState(
          status: PresenceStatus.cooldown,
          trackingId: _cooldownTrackingId,
          cooldownEndsAt: now.add(remaining),
          details: 'Cooldown active (no customer)',
        );
      } else {
        // Cooldown complete
        _resetTracking();
        if (onCooldownComplete != null) {
          onCooldownComplete!();
        }
        return PresenceState(
          status: PresenceStatus.idle,
          details: 'Cooldown complete',
        );
      }
    }

    if (_referenceTrackingId != null && !_priceIncreased) {
      // Person left before threshold
      if (_anyPriceIncreaseOccurred) {
        // A previous person triggered a price increase, so start cooldown
        _cooldownTrackingId = _referenceTrackingId;
        _startCooldown();

        final remaining = _getCooldownRemaining();
        return PresenceState(
          status: PresenceStatus.cooldown,
          trackingId: _cooldownTrackingId,
          cooldownEndsAt: remaining != null ? now.add(remaining) : null,
          details: 'Person left, cooldown started',
        );
      }

      // No price increase occurred at all, just reset
      _resetTracking();
      return PresenceState(
        status: PresenceStatus.idle,
        details: 'Person left (no price increase)',
      );
    } else if (_anyPriceIncreaseOccurred) {
      // Person left after price increased - check grace period before cooldown
      if (_lastFaceSeenTime == null) {
        // First frame without face after price increase
        _lastFaceSeenTime = now;
        return PresenceState(
          status: PresenceStatus.priceIncreased,
          trackingId: _referenceTrackingId,
          triggeredAt: _triggeredAt,
          details: 'Checking if person left...',
        );
      }

      final absenceDuration = now.difference(_lastFaceSeenTime!);

      if (absenceDuration >= _absenceGracePeriod) {
        // Face has been absent for grace period - start cooldown
        _cooldownTrackingId = _referenceTrackingId; // Save before clearing
        _startCooldown();

        final remaining = _getCooldownRemaining();
        return PresenceState(
          status: PresenceStatus.cooldown,
          trackingId: _cooldownTrackingId,
          cooldownEndsAt: remaining != null ? now.add(remaining) : null,
          details: 'Person left, cooldown active',
        );
      } else {
        // Still in grace period
        final remaining = _absenceGracePeriod - absenceDuration;
        return PresenceState(
          status: PresenceStatus.priceIncreased,
          trackingId: _referenceTrackingId,
          triggeredAt: _triggeredAt,
          details: 'Face lost (${remaining.inSeconds}s grace period)',
        );
      }
    }

    return PresenceState(
      status: PresenceStatus.idle,
      details: 'Waiting for customer',
    );
  }

  PresenceState _handleFaceDetected(int trackingId, DateTime now) {
    // If in cooldown, pause it but don't ignore the face
    if (_cooldownStartTime != null) {
      // Pause cooldown - update accumulated time
      if (_cooldownPausedAt == null) {
        // Calculate how much time has passed since cooldown started or resumed
        final elapsed = now.difference(_cooldownStartTime!);
        _cooldownAccumulatedTime += elapsed;
        _cooldownPausedAt = now;
        debugPrint(
          'Cooldown paused. Accumulated: ${_cooldownAccumulatedTime.inSeconds}s',
        );
      }

      final remaining = _getCooldownRemaining();
      return PresenceState(
        status: PresenceStatus.cooldown,
        trackingId: _cooldownTrackingId,
        cooldownEndsAt: remaining != null ? now.add(remaining) : null,
        details: 'Cooldown paused (customer present)',
      );
    }

    // If no reference tracking ID, this is the first person
    if (_referenceTrackingId == null) {
      _referenceTrackingId = trackingId;
      _trackingStartTime = now;
      _lastFaceSeenTime = null;
      _priceIncreased = false;

      return PresenceState(
        status: PresenceStatus.tracking,
        trackingId: trackingId,
        presenceDuration: Duration.zero,
        details: 'Started tracking customer',
      );
    }

    // Check if same person
    if (trackingId == _referenceTrackingId) {
      // Reset last face seen time since face is detected
      _lastFaceSeenTime = null;

      final duration = now.difference(_trackingStartTime!);

      // Check if 15s threshold crossed
      if (!_priceIncreased && duration >= _presenceThreshold) {
        _priceIncreased = true;
        _anyPriceIncreaseOccurred =
            true; // Mark that at least one increase happened
        _triggeredAt = now;

        // Trigger callback
        if (onPriceIncrease != null) {
          onPriceIncrease!(trackingId);
        }

        return PresenceState(
          status: PresenceStatus.priceIncreased,
          trackingId: trackingId,
          presenceDuration: duration,
          triggeredAt: _triggeredAt,
          details: 'Price increased!',
        );
      }

      // Still tracking, haven't reached threshold yet
      return PresenceState(
        status: _priceIncreased
            ? PresenceStatus.priceIncreased
            : PresenceStatus.tracking,
        trackingId: trackingId,
        presenceDuration: duration,
        triggeredAt: _triggeredAt,
        details: _priceIncreased
            ? 'Price already increased'
            : 'Tracking: ${duration.inSeconds}s / ${_presenceThreshold.inSeconds}s',
      );
    } else {
      // Different person detected

      // If we're in cooldown, don't reset - keep cooldown active
      if (_cooldownStartTime != null) {
        // Already in cooldown - pause it and continue
        if (_cooldownPausedAt == null) {
          final elapsed = now.difference(_cooldownStartTime!);
          _cooldownAccumulatedTime += elapsed;
          _cooldownPausedAt = now;
          debugPrint(
            'Different person during cooldown. Cooldown paused. Accumulated: ${_cooldownAccumulatedTime.inSeconds}s',
          );
        }

        final remaining = _getCooldownRemaining();
        return PresenceState(
          status: PresenceStatus.cooldown,
          trackingId: _cooldownTrackingId,
          cooldownEndsAt: remaining != null ? now.add(remaining) : null,
          details: 'Cooldown paused (different customer)',
        );
      }

      // If price was increased for current person, reset and track new person
      // This allows stacking price increases from multiple people
      if (_priceIncreased) {
        debugPrint(
          'Different person detected after price increase. Resetting to track new person.',
        );
      }

      // Reset and track new person (allows stacking)
      debugPrint(
        'Different person detected: old=$_referenceTrackingId, new=$trackingId',
      );

      // Save the price increase flag before resetting
      final preserveAnyIncrease = _anyPriceIncreaseOccurred;
      _resetTracking();
      // Restore the flag - we only fully reset after cooldown completes
      _anyPriceIncreaseOccurred = preserveAnyIncrease;

      // Start tracking new person
      _referenceTrackingId = trackingId;
      _trackingStartTime = now;
      _lastFaceSeenTime = null;
      _priceIncreased = false;

      return PresenceState(
        status: PresenceStatus.tracking,
        trackingId: trackingId,
        presenceDuration: Duration.zero,
        details: 'New customer detected',
      );
    }
  }

  void _startCooldown() {
    _cooldownStartTime = DateTime.now();
    _cooldownPausedAt = null;
    _cooldownAccumulatedTime = Duration.zero;
    debugPrint('Cooldown started at: $_cooldownStartTime');

    // Clear tracking state but keep cooldown timer
    _referenceTrackingId = null;
    _trackingStartTime = null;
    _triggeredAt = null;
    _lastFaceSeenTime = null;
    _priceIncreased = false;
  }

  Duration? _getCooldownRemaining() {
    if (_cooldownStartTime == null) return null;

    final now = DateTime.now();
    Duration totalElapsed = _cooldownAccumulatedTime;

    // If not paused, add time since cooldown started/resumed
    if (_cooldownPausedAt == null) {
      totalElapsed += now.difference(_cooldownStartTime!);
    }

    final remaining = _cooldownDuration - totalElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _resetTracking() {
    debugPrint('Resetting tracking (old ID: $_referenceTrackingId)');
    _referenceTrackingId = null;
    _trackingStartTime = null;
    _triggeredAt = null;
    _cooldownStartTime = null;
    _cooldownPausedAt = null;
    _cooldownAccumulatedTime = Duration.zero;
    _lastFaceSeenTime = null;
    _cooldownTrackingId = null;
    _priceIncreased = false;
    _anyPriceIncreaseOccurred = false; // Reset global flag
  }

  PresenceState _getCurrentState({String? details}) {
    final now = DateTime.now();

    // Check cooldown
    if (_cooldownStartTime != null) {
      final remaining = _getCooldownRemaining();
      if (remaining != null && remaining > Duration.zero) {
        return PresenceState(
          status: PresenceStatus.cooldown,
          trackingId: _cooldownTrackingId,
          cooldownEndsAt: now.add(remaining),
          details: details ?? 'Cooldown active',
        );
      }
    }

    // If tracking someone
    if (_referenceTrackingId != null && _trackingStartTime != null) {
      final duration = now.difference(_trackingStartTime!);

      return PresenceState(
        status: _priceIncreased
            ? PresenceStatus.priceIncreased
            : PresenceStatus.tracking,
        trackingId: _referenceTrackingId,
        presenceDuration: duration,
        triggeredAt: _triggeredAt,
        details: details,
      );
    }

    return PresenceState(status: PresenceStatus.idle, details: details);
  }

  /// Manually reset tracking (e.g., when monitoring stops)
  void reset() {
    _resetTracking();
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Concatenate all plane bytes
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final inputImageFormat = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );
      if (inputImageFormat == null) {
        debugPrint('Unknown image format: ${image.format.raw}');
        return null;
      }

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: InputImageRotation.rotation0deg,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
