/// Represents a listed item in the BumpBox system
class Item {
  final String id;
  final String name;
  final String description;
  final double startingPrice;
  final double floorPrice; // Seller-set minimum acceptable price
  final DateTime listedAt;
  final Duration listingDuration;
  final String? paymentLink; // Stripe payment link for purchasing

  const Item({
    required this.id,
    required this.name,
    required this.description,
    required this.startingPrice,
    required this.floorPrice,
    required this.listedAt,
    this.listingDuration = const Duration(days: 7),
    this.paymentLink,
  });

  /// Calculate how long the item has been listed
  Duration getAge(DateTime now) {
    return now.difference(listedAt);
  }

  /// Get hours elapsed since listing
  double getHoursElapsed(DateTime now) {
    return getAge(now).inMinutes / 60.0;
  }

  /// Get days elapsed since listing
  double getDaysElapsed(DateTime now) {
    return getAge(now).inHours / 24.0;
  }

  /// Check if listing has expired
  bool isExpired(DateTime now) {
    return getAge(now) >= listingDuration;
  }

  /// Get time remaining before listing expires
  Duration getTimeRemaining(DateTime now) {
    final age = getAge(now);
    if (age >= listingDuration) {
      return Duration.zero;
    }
    return listingDuration - age;
  }

  /// Get percentage of listing time elapsed (0.0 to 1.0)
  double getListingProgress(DateTime now) {
    final hoursElapsed = getHoursElapsed(now);
    final totalHours = listingDuration.inMinutes / 60.0;
    final progress = hoursElapsed / totalHours;
    return progress.clamp(0.0, 1.0);
  }

  /// Format time remaining as human-readable string
  String formatTimeRemaining(DateTime now) {
    final remaining = getTimeRemaining(now);
    if (remaining == Duration.zero) {
      return 'Expired';
    }

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;

    if (days > 0) {
      return '$days day${days == 1 ? '' : 's'} ${hours}h remaining';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else {
      return '${minutes}m remaining';
    }
  }

  @override
  String toString() {
    return 'Item(id: $id, name: $name, startingPrice: \$${startingPrice.toStringAsFixed(2)}, '
        'floorPrice: \$${floorPrice.toStringAsFixed(2)}, listedAt: $listedAt, paymentLink: $paymentLink)';
  }
}
