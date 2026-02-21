/// Result from ESP32 camera object detection
class DetectionResult {
  final String label;
  final String category;
  final int minPrice;
  final int maxPrice;
  final int confidence;
  final DateTime timestamp;
  final String? lockerId;

  const DetectionResult({
    required this.label,
    required this.category,
    required this.minPrice,
    required this.maxPrice,
    required this.confidence,
    required this.timestamp,
    this.lockerId,
  });

  /// Create from JSON response from backend
  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final detection = json['detection'] as Map<String, dynamic>?;
    if (detection == null) {
      throw FormatException('Missing detection object in JSON response');
    }

    return DetectionResult(
      label: detection['label'] as String? ?? 'Unknown',
      category: detection['category'] as String? ?? 'Uncategorized',
      minPrice: detection['minPrice'] as int? ?? 0,
      maxPrice: detection['maxPrice'] as int? ?? 0,
      confidence: detection['confidence'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      lockerId: json['lockerId'] as String?,
    );
  }

  /// Get price range as formatted string
  String get priceRangeString => '\$$minPrice - \$$maxPrice';

  /// Get confidence as formatted percentage
  String get confidenceString => '$confidence%';

  /// Check if detection is high confidence (>= 80%)
  bool get isHighConfidence => confidence >= 80;

  /// Get suggested starting price (uses max price)
  double get suggestedStartingPrice => maxPrice.toDouble();

  /// Get suggested floor price (uses min price)
  double get suggestedFloorPrice => minPrice.toDouble();

  @override
  String toString() {
    return 'DetectionResult(label: $label, category: $category, '
        'price: \$$minPrice-\$$maxPrice, confidence: $confidence%)';
  }
}
