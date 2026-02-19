import 'dart:math';
import '../models/item.dart';
import '../config/pricing_config.dart';

/// Service for calculating dynamic prices with time-decay and surge pricing
class PricingService {
  /// Calculate the current time-decay base price for an item
  ///
  /// Uses exponential decay formula:
  /// price = floorPrice + (startingPrice - floorPrice) * decayBase^hoursElapsed
  ///
  /// This creates a curve where:
  /// - Price starts at startingPrice
  /// - Decays rapidly initially, then slows down
  /// - Reaches approximately halfway at the half-life point
  /// - Approaches (but never goes below) floorPrice
  static double calculateTimeDecayPrice(Item item, DateTime now) {
    final hoursElapsed = item.getHoursElapsed(now);

    // If expired, return floor price
    if (item.isExpired(now)) {
      return item.floorPrice;
    }

    // Exponential decay calculation
    final priceRange = item.startingPrice - item.floorPrice;
    final decayFactor = pow(PricingConfig.decayBase, hoursElapsed);
    final decayedPrice = item.floorPrice + (priceRange * decayFactor);

    // Ensure price never goes below floor
    return max(decayedPrice, item.floorPrice);
  }

  /// Calculate surge price multiplier based on attention events
  ///
  /// Applies compound multiplier: surgeMultiplier^surgeCount
  /// Example: 1.05^3 = 1.157625 (15.76% increase for 3 events)
  static double calculateSurgeMultiplier(int surgeCount) {
    if (surgeCount <= 0) {
      return 1.0;
    }

    // Cap surge count to prevent excessive pricing
    final cappedCount = min(surgeCount, PricingConfig.maxSurgeCount);

    return pow(PricingConfig.surgeMultiplier, cappedCount).toDouble();
  }

  /// Calculate surge-adjusted price from base decay price
  static double calculateSurgePrice(double decayBasePrice, int surgeCount) {
    final multiplier = calculateSurgeMultiplier(surgeCount);
    return decayBasePrice * multiplier;
  }

  /// Get the final displayed price combining decay and surge
  ///
  /// This is the main method to get current price:
  /// 1. Calculate time-decay base price
  /// 2. Apply surge multiplier on top
  /// 3. Ensure result never goes below floor price
  static double getFinalPrice(Item item, int surgeCount, DateTime now) {
    final decayPrice = calculateTimeDecayPrice(item, now);
    final surgedPrice = calculateSurgePrice(decayPrice, surgeCount);

    // Enforce floor price as absolute minimum
    return max(surgedPrice, item.floorPrice);
  }

  /// Calculate the surge offset (how much surge adds to decay price)
  static double calculateSurgeOffset(double decayBasePrice, int surgeCount) {
    final surgedPrice = calculateSurgePrice(decayBasePrice, surgeCount);
    return surgedPrice - decayBasePrice;
  }

  /// Get percentage discount from starting price
  static double getDiscountPercentage(Item item, double currentPrice) {
    if (item.startingPrice <= 0) return 0.0;
    final discount = (item.startingPrice - currentPrice) / item.startingPrice;
    return (discount * 100.0).clamp(0.0, 100.0);
  }

  /// Check if price is at floor (fully decayed)
  static bool isAtFloor(double price, double floorPrice) {
    const epsilon = 0.01; // Within 1 cent
    return (price - floorPrice).abs() < epsilon;
  }

  /// Estimate time until price reaches floor (assuming no surge)
  /// Returns null if already at floor or calculation isn't feasible
  static Duration? estimateTimeToFloor(Item item, DateTime now) {
    final currentDecayPrice = calculateTimeDecayPrice(item, now);

    if (isAtFloor(currentDecayPrice, item.floorPrice)) {
      return Duration.zero;
    }

    // For exponential decay, price approaches floor asymptotically
    // We'll estimate when it reaches within 1% of floor
    const targetPercent = 0.01;
    final priceRange = item.startingPrice - item.floorPrice;
    final targetPrice = item.floorPrice + (priceRange * targetPercent);

    // Solve for hours: targetPrice = floor + range * decayBase^hours
    // (targetPrice - floor) / range = decayBase^hours
    // hours = log((targetPrice - floor) / range) / log(decayBase)

    final ratio = (targetPrice - item.floorPrice) / priceRange;
    if (ratio <= 0) return Duration.zero;

    final hoursToTarget = log(ratio) / log(PricingConfig.decayBase);
    final hoursRemaining = hoursToTarget - item.getHoursElapsed(now);

    if (hoursRemaining <= 0) {
      return Duration.zero;
    }

    return Duration(minutes: (hoursRemaining * 60).round());
  }
}
