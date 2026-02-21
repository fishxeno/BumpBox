enum PresenceStatus {
  idle, // No person detected, waiting
  tracking, // Person detected and being tracked
  priceIncreased, // 15s threshold crossed, price increased
  cooldown, // Person left, in 5-minute cooldown
}

class PresenceState {
  final PresenceStatus status;
  final int? trackingId;
  final Duration presenceDuration;
  final DateTime? triggeredAt;
  final DateTime? cooldownEndsAt;
  final String? details;
  final DateTime timestamp;

  PresenceState({
    required this.status,
    this.trackingId,
    Duration? presenceDuration,
    this.triggeredAt,
    this.cooldownEndsAt,
    this.details,
    DateTime? timestamp,
  }) : presenceDuration = presenceDuration ?? Duration.zero,
       timestamp = timestamp ?? DateTime.now();

  bool get isPriceIncreased => status == PresenceStatus.priceIncreased;
  bool get isTracking => status == PresenceStatus.tracking;
  bool get isInCooldown => status == PresenceStatus.cooldown;
  bool get isIdle => status == PresenceStatus.idle;

  Duration? get remainingCooldown {
    if (cooldownEndsAt == null) return null;
    final remaining = cooldownEndsAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  String toString() {
    return 'PresenceState(status: $status, trackingId: $trackingId, '
        'duration: ${presenceDuration.inSeconds}s, details: $details)';
  }
}
