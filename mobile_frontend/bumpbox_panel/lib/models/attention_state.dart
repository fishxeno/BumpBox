enum AttentionStatus {
  payingAttention,
  notPayingAttention,
  noFaceDetected,
  unknown,
}

class AttentionState {
  final AttentionStatus status;
  final double confidence;
  final String? details;
  final DateTime timestamp;

  AttentionState({
    required this.status,
    required this.confidence,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isPayingAttention => status == AttentionStatus.payingAttention;

  @override
  String toString() {
    return 'AttentionState(status: $status, confidence: ${confidence.toStringAsFixed(2)}, details: $details)';
  }
}

class FaceMetrics {
  final bool faceDetected;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? headPitch;
  final double? headYaw;
  final double? headRoll;
  final double? faceSize;

  FaceMetrics({
    required this.faceDetected,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headPitch,
    this.headYaw,
    this.headRoll,
    this.faceSize,
  });

  bool get eyesOpen {
    if (leftEyeOpenProbability == null || rightEyeOpenProbability == null) {
      return false;
    }
    return (leftEyeOpenProbability! > 0.8 && rightEyeOpenProbability! > 0.8);
  }

  bool get headFacingScreen {
    if (headPitch == null || headYaw == null) return false;
    return (headPitch!.abs() < 20 && headYaw!.abs() < 30);
  }

  @override
  String toString() {
    return 'FaceMetrics(detected: $faceDetected, leftEye: ${leftEyeOpenProbability?.toStringAsFixed(2)}, '
        'rightEye: ${rightEyeOpenProbability?.toStringAsFixed(2)}, '
        'pitch: ${headPitch?.toStringAsFixed(1)}°, yaw: ${headYaw?.toStringAsFixed(1)}°)';
  }
}
