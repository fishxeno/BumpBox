/// API configuration for BumpBox backend integration
class ApiConfig {
  /// Base URL for the backend server
  static const String baseUrl =
      'http://bumpbox-env-1.eba-43hmmxwt.ap-southeast-1.elasticbeanstalk.com';

  /// Endpoint to trigger ESP32 camera capture
  static const String triggerCaptureEndpoint = '/api/locker/trigger-capture';

  /// Endpoint to fetch latest detection result
  static const String latestDetectionEndpoint = '/api/detections/latest';

  /// Endpoint to create a new item listing
  static const String createItemEndpoint = '/api/item';

  /// Polling interval for checking detection results
  static const Duration pollInterval = Duration(seconds: 2);

  /// Timeout for detection polling (30 seconds)
  static const Duration detectionTimeout = Duration(seconds: 30);

  /// Default locker ID (for single-locker setup)
  static const String defaultLockerId = 'locker1';

  /// Full URL for trigger capture
  static String get triggerCaptureUrl => '$baseUrl$triggerCaptureEndpoint';

  /// Full URL for latest detection
  static String get latestDetectionUrl => '$baseUrl$latestDetectionEndpoint';

  /// Full URL for creating items
  static String get createItemUrl => '$baseUrl$createItemEndpoint';
}
