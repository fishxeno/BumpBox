import 'dart:math';

/// Configuration constants for the BumpBox pricing system
class PricingConfig {
  // ===== Time Decay Settings =====

  /// Default listing duration (7 days as per PRD)
  static const Duration listingDuration = Duration(days: 7);

  /// Exponential decay half-life in hours
  /// After this time, price will be halfway between starting and floor price
  /// 84 hours = 3.5 days (middle of 7-day period)
  static const double decayHalfLifeHours = 84.0;

  /// Exponential decay base calculated from half-life
  /// Formula: decayBase = 0.5^(1/halfLife)
  static final double decayBase = pow(0.2, 1.0 / decayHalfLifeHours).toDouble();

  /// How often to recalculate decay price (in seconds)
  static const Duration decayUpdateInterval = Duration(seconds: 10);

  // ===== Surge Pricing Settings =====

  /// Multiplier applied per attention/interest event (1%)
  static const double surgeMultiplier = 1.01;

  /// Maximum surge multiplier to prevent runaway pricing
  static const double maxSurgeMultiplier = 1.50; // 50% max increase

  /// Calculate max surge count based on max multiplier
  static int get maxSurgeCount {
    if (surgeMultiplier <= 1.0) return 0;
    return (log(maxSurgeMultiplier) / log(surgeMultiplier)).floor();
  }

  // ===== Physical Attention Settings =====

  /// Dwell time required to trigger physical attention surge (5s for testing, 15s in PRD)
  static const Duration physicalPresenceThreshold = Duration(seconds: 5);

  /// Cooldown period after person leaves before price resets surge (5s for testing, 5min in PRD)
  static const Duration surgeCooldownDuration = Duration(seconds: 5);

  /// Grace period for person absence before cooldown starts
  static const Duration absenceGracePeriod = Duration(seconds: 3);

  // ===== Online Interest Settings (Mock) =====

  /// How often to poll for online interest (mock backend)
  static const Duration onlineInterestPollInterval = Duration(seconds: 5);

  /// Click threshold within time window to trigger online surge
  static const int onlineClickThreshold = 10;

  /// Page view threshold within time window to trigger online surge
  static const int onlineViewThreshold = 15;

  /// Time window for measuring online activity spikes
  static const Duration onlineActivityWindow = Duration(minutes: 5);

  /// Probability (0.0 to 1.0) of simulated online surge per poll
  static const double mockOnlineSurgeProbability = 0.01; // 1% chance every poll

  // ===== Display Settings =====

  /// Decimal places to show for prices
  static const int priceDecimalPlaces = 2;

  /// Show cents if enabled, otherwise round to nearest dollar
  static const bool showCents = true;

  /// Format price as string
  static String formatPrice(double price) {
    if (showCents) {
      return '\$${price.toStringAsFixed(priceDecimalPlaces)}';
    } else {
      return '\$${price.round()}';
    }
  }
}
