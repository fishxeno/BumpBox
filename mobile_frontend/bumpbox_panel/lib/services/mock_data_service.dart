import 'dart:math';
import '../models/item.dart';
import '../config/pricing_config.dart';

/// Mock data service simulating backend API responses
///
/// In production, this would be replaced with real HTTP calls to backend
class MockDataService {
  static final Random _random = Random();

  /// Get a mock item for display on the kiosk
  ///
  /// Simulates an item that was listed 2 days ago
  static Item getMockItem() {
    final now = DateTime.now();
    final listedAt = now.subtract(const Duration(days: 2, hours: 3));

    return Item(
      id: 'item_001',
      name: 'Bose QuietComfort 35 II',
      description:
          'Wireless noise-cancelling headphones in excellent condition. '
          'Occasionally used, includes original case and cables. '
          'Battery life still excellent.',
      startingPrice: 150.0,
      floorPrice: 80.0,
      listedAt: listedAt,
      listingDuration: PricingConfig.listingDuration,
    );
  }

  /// Get simulated online interest metrics
  ///
  /// In production, this would fetch from backend API:
  /// GET /api/items/{id}/online-interest
  static OnlineInterest getSimulatedOnlineInterest() {
    // Simulate random but realistic metrics
    final pageViews = _random.nextInt(50) + 5; // 5-55 views
    final clickCount = _random.nextInt(20); // 0-20 clicks
    final wishlistAdds = _random.nextInt(5); // 0-5 wishlist adds
    final lastActivity = DateTime.now().subtract(
      Duration(seconds: _random.nextInt(300)), // Within last 5 minutes
    );

    return OnlineInterest(
      pageViews: pageViews,
      clickCount: clickCount,
      wishlistAdds: wishlistAdds,
      lastActivity: lastActivity,
    );
  }

  /// Determine if online interest should trigger a surge event
  ///
  /// This simulates backend logic that analyzes online metrics
  /// and decides whether interest is high enough to increase price
  static bool shouldTriggerOnlineSurge() {
    // Simple probability-based simulation for now
    // In production, backend would analyze actual traffic patterns
    return _random.nextDouble() < PricingConfig.mockOnlineSurgeProbability;
  }

  /// Get realistic online interest that fluctuates
  ///
  /// Simulates time-of-day patterns and random spikes
  static OnlineInterest getRealisticOnlineInterest() {
    final now = DateTime.now();
    final hour = now.hour;

    // Higher activity during peak hours (10am-2pm, 6pm-9pm)
    final isPeakHour = (hour >= 10 && hour <= 14) || (hour >= 18 && hour <= 21);
    final activityMultiplier = isPeakHour ? 2.0 : 1.0;

    // Base metrics with random variation
    final baseViews = (_random.nextInt(30) + 10) * activityMultiplier;
    final baseClicks = (_random.nextInt(10) + 2) * activityMultiplier;
    final baseWishlist = _random.nextInt(3);

    // Occasional spikes (10% chance of high activity)
    final isSpike = _random.nextDouble() < 0.1;
    final spikeMultiplier = isSpike ? 3.0 : 1.0;

    return OnlineInterest(
      pageViews: (baseViews * spikeMultiplier).round(),
      clickCount: (baseClicks * spikeMultiplier).round(),
      wishlistAdds: baseWishlist,
      lastActivity: now.subtract(Duration(seconds: _random.nextInt(60))),
    );
  }
}

/// Represents online interest metrics for an item
class OnlineInterest {
  final int pageViews;
  final int clickCount;
  final int wishlistAdds;
  final DateTime lastActivity;

  const OnlineInterest({
    required this.pageViews,
    required this.clickCount,
    required this.wishlistAdds,
    required this.lastActivity,
  });

  /// Check if metrics indicate high interest worthy of surge pricing
  bool shouldTriggerSurge() {
    // Surge if clicks or views exceed thresholds within activity window
    final timeSinceActivity = DateTime.now().difference(lastActivity);
    final isRecent = timeSinceActivity <= PricingConfig.onlineActivityWindow;

    if (!isRecent) return false;

    return clickCount >= PricingConfig.onlineClickThreshold ||
        pageViews >= PricingConfig.onlineViewThreshold ||
        wishlistAdds >= 3;
  }

  /// Get total interest score (weighted sum of metrics)
  int getTotalScore() {
    return (clickCount * 3) + pageViews + (wishlistAdds * 5);
  }

  @override
  String toString() {
    return 'OnlineInterest(views: $pageViews, clicks: $clickCount, '
        'wishlist: $wishlistAdds, lastActivity: $lastActivity)';
  }
}
