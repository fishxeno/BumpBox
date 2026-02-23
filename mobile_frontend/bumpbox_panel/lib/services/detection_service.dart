import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/detection_result.dart';

/// Service for managing ESP32 camera detection
class DetectionService {
  /// Trigger ESP32 camera capture via backend
  ///
  /// Sends a request to the backend which sets a flag that the ESP32
  /// will poll and detect. When detected, ESP32 will capture and send
  /// image for object detection.
  static Future<void> triggerCapture({String? lockerId}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.triggerCaptureUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lockerId': lockerId ?? ApiConfig.defaultLockerId}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to trigger capture: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception('Backend returned failure: ${data['message']}');
      }
    } catch (e) {
      throw Exception('Failed to trigger capture: $e');
    }
  }

  /// Fetch latest detection result from backend
  ///
  /// Returns null if no detection is available or if the detection
  /// is older than the provided 'since' timestamp.
  static Future<DetectionResult?> fetchLatestDetection({
    DateTime? since,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.latestDetectionUrl).replace(
        queryParameters: since != null
            ? {'since': since.toIso8601String()}
            : null,
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch detection: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      // Backend returns { detection: null } if no detection available
      if (data['detection'] == null) {
        return null;
      }

      return DetectionResult.fromJson(data);
    } catch (e) {
      // For polling, we don't want to throw on network errors
      // Just return null and let the caller retry
      print('[DetectionService] Error fetching detection: $e');
      return null;
    }
  }

  /// Poll for detection result with timeout
  ///
  /// Continuously polls the backend for a detection result until one
  /// is available or the timeout is reached. Returns the detection
  /// result or null if timeout occurs.
  static Future<DetectionResult?> pollForDetection({
    Duration? timeout,
    Duration? pollInterval,
    DateTime? since,
  }) async {
    final timeoutDuration = timeout ?? ApiConfig.detectionTimeout;
    final pollIntervalDuration = pollInterval ?? ApiConfig.pollInterval;
    final startTime = DateTime.now();
    final sinceTime = since ?? startTime;

    while (DateTime.now().difference(startTime) < timeoutDuration) {
      final result = await fetchLatestDetection(since: sinceTime);

      if (result != null) {
        return result;
      }

      // Wait before next poll
      await Future.delayed(pollIntervalDuration);
    }

    // Timeout reached
    return null;
  }
}
