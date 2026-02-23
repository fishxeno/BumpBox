import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';

/// Service for persisting app state across restarts
class StorageService {
  static const String _keyItemId = 'current_item_id';
  static const String _keyItemName = 'current_item_name';
  static const String _keyItemDescription = 'current_item_description';
  static const String _keyItemStartingPrice = 'current_item_starting_price';
  static const String _keyItemFloorPrice = 'current_item_floor_price';
  static const String _keyItemListedAt = 'current_item_listed_at';
  static const String _keyItemListingDurationDays =
      'current_item_listing_duration_days';
  static const String _keySurgeCount = 'surge_count';
  static const String _keyPhysicalSurgeCount = 'physical_surge_count';
  static const String _keyOnlineSurgeCount = 'online_surge_count';
  static const String _keyLastPriceUpdate = 'last_price_update';

  /// Save current item to local storage
  static Future<void> saveItem(Item item) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyItemId, item.id);
    await prefs.setString(_keyItemName, item.name);
    await prefs.setString(_keyItemDescription, item.description);
    await prefs.setDouble(_keyItemStartingPrice, item.startingPrice);
    await prefs.setDouble(_keyItemFloorPrice, item.floorPrice);
    await prefs.setString(_keyItemListedAt, item.listedAt.toIso8601String());
    await prefs.setInt(
      _keyItemListingDurationDays,
      item.listingDuration.inDays,
    );
  }

  /// Load item from local storage
  static Future<Item?> loadItem() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString(_keyItemId);
    if (id == null) return null;

    final name = prefs.getString(_keyItemName);
    final description = prefs.getString(_keyItemDescription);
    final startingPrice = prefs.getDouble(_keyItemStartingPrice);
    final floorPrice = prefs.getDouble(_keyItemFloorPrice);
    final listedAtStr = prefs.getString(_keyItemListedAt);
    final listingDurationDays = prefs.getInt(_keyItemListingDurationDays);

    if (name == null ||
        description == null ||
        startingPrice == null ||
        floorPrice == null ||
        listedAtStr == null ||
        listingDurationDays == null) {
      return null;
    }

    try {
      final listedAt = DateTime.parse(listedAtStr);
      return Item(
        id: id,
        name: name,
        description: description,
        startingPrice: startingPrice,
        floorPrice: floorPrice,
        listedAt: listedAt,
        listingDuration: Duration(days: listingDurationDays),
      );
    } catch (e) {
      return null;
    }
  }

  /// Save surge counts
  static Future<void> saveSurgeCounts({
    required int surgeCount,
    required int physicalSurgeCount,
    required int onlineSurgeCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_keySurgeCount, surgeCount);
    await prefs.setInt(_keyPhysicalSurgeCount, physicalSurgeCount);
    await prefs.setInt(_keyOnlineSurgeCount, onlineSurgeCount);
  }

  /// Load surge counts
  static Future<Map<String, int>> loadSurgeCounts() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'surgeCount': prefs.getInt(_keySurgeCount) ?? 0,
      'physicalSurgeCount': prefs.getInt(_keyPhysicalSurgeCount) ?? 0,
      'onlineSurgeCount': prefs.getInt(_keyOnlineSurgeCount) ?? 0,
    };
  }

  /// Save last price update timestamp
  static Future<void> saveLastPriceUpdate(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPriceUpdate, timestamp.toIso8601String());
  }

  /// Load last price update timestamp
  static Future<DateTime?> loadLastPriceUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_keyLastPriceUpdate);

    if (timestampStr == null) return null;

    try {
      return DateTime.parse(timestampStr);
    } catch (e) {
      return null;
    }
  }

  /// Clear all stored data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Check if there's saved state available
  static Future<bool> hasSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyItemId);
  }
}
