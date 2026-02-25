import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/item.dart';
import '../config/pricing_config.dart';

/// Service for fetching items from the backend API
class ItemApiService {
  /// Fetch the latest listed item from the backend
  ///
  /// Returns null if no item is found or an error occurs.
  /// The backend returns the most recently listed item.
  static Future<Item?> fetchLatestItem() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getItemUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 404) {
        // No item found
        print('[ItemApiService] No item found in backend');
        return null;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch item: ${response.statusCode} ${response.body}',
        );
      }

      final jsonData = jsonDecode(response.body);

      // Backend response structure:
      // {
      //   "status": true/false,  // true if sold, false if not sold
      //   "message": "...",
      //   "data": { item fields }
      // }

      if (jsonData['data'] == null) {
        print('[ItemApiService] No item data in response');
        return null;
      }

      // Extract the status field to determine if item is sold
      final isSold = jsonData['status'] == true;

      return _parseItemFromBackend(jsonData['data'], isSold: isSold);
    } catch (e) {
      print('[ItemApiService] Error fetching item: $e');
      return null;
    }
  }

  /// Parse backend item data into Item model
  ///
  /// Backend provides:
  /// - itemid: database ID
  /// - item_name: item name
  /// - price: current/starting price
  /// - description: item description (if available)
  /// - datetime_expire: expiration timestamp
  /// - sale_status: 0 (not sold) or 1 (sold)
  /// - paymentLink: Stripe payment link URL
  ///
  /// We map these to the Item model's fields:
  /// - id: from itemid
  /// - name: from item_name
  /// - description: from description or default
  /// - startingPrice: from price
  /// - floorPrice: calculated as 50% of starting price (backend doesn't store this yet)
  /// - listedAt: calculated from datetime_expire - listingDuration
  /// - listingDuration: from pricing config
  /// - paymentLink: from paymentLink
  /// - isSold: whether the item has been sold (from status field)
  static Item _parseItemFromBackend(
    Map<String, dynamic> data, {
    bool isSold = false,
  }) {
    final itemId = data['itemid']?.toString() ?? 'unknown';
    final itemName = data['item_name']?.toString() ?? 'Unknown Item';
    final price = _parsePrice(data['price']);
    final description =
        data['description']?.toString() ??
        'High-quality item available for purchase';
    final paymentLink = data['paymentLink']?.toString();

    // Parse expiration date to calculate listing time
    final expirationDate = _parseDateTime(data['datetime_expire']);

    // Calculate listedAt as (expirationDate - listingDuration)
    final listedAt = expirationDate.subtract(PricingConfig.listingDuration);

    return Item(
      id: itemId,
      name: itemName,
      description: description,
      startingPrice: price * 1.15, // Add 15% markup for starting price
      floorPrice: price,
      listedAt: listedAt,
      listingDuration: PricingConfig.listingDuration,
      paymentLink: paymentLink,
      isSold: isSold,
    );
  }

  /// Parse price from backend (can be string or number)
  static double _parsePrice(dynamic priceData) {
    if (priceData == null) return 100.0; // Default fallback

    if (priceData is num) {
      return priceData.toDouble();
    }

    if (priceData is String) {
      return double.tryParse(priceData) ?? 100.0;
    }

    return 100.0;
  }

  /// Parse datetime from backend
  ///
  /// Backend stores datetime_expire as MySQL DATETIME format
  /// (e.g., "2024-01-15 14:30:00")
  static DateTime _parseDateTime(dynamic dateData) {
    if (dateData == null) {
      // Default to 7 days from now if no expiration
      return DateTime.now().add(PricingConfig.listingDuration);
    }

    if (dateData is String) {
      try {
        // Try parsing ISO 8601 format
        return DateTime.parse(dateData);
      } catch (e) {
        // Try parsing MySQL datetime format (YYYY-MM-DD HH:MM:SS)
        try {
          final parts = dateData.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');

            if (dateParts.length == 3 && timeParts.length == 3) {
              return DateTime(
                int.parse(dateParts[0]), // year
                int.parse(dateParts[1]), // month
                int.parse(dateParts[2]), // day
                int.parse(timeParts[0]), // hour
                int.parse(timeParts[1]), // minute
                int.parse(timeParts[2]), // second
              );
            }
          }
        } catch (e) {
          print('[ItemApiService] Error parsing datetime: $e');
        }
      }
    }

    // Fallback to 7 days from now
    return DateTime.now().add(PricingConfig.listingDuration);
  }

  /// Check if the latest item's payment has been completed
  ///
  /// Returns true if the item's sale_status == 1 (sold),
  /// false if sale_status == 0 (not sold),
  /// or null if an error occurs.
  ///
  /// This is used for polling to detect when a payment completes.
  static Future<bool?> checkPaymentStatus() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getItemUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        print(
          '[ItemApiService] Payment status check failed: ${response.statusCode}',
        );
        return null;
      }

      final jsonData = jsonDecode(response.body);

      // Backend returns { "status": true } when item is sold
      // and { "status": false } when item is not sold
      return jsonData['status'] == true;
    } catch (e) {
      print('[ItemApiService] Error checking payment status: $e');
      return null;
    }
  }

  /// Update the price of the latest item
  ///
  /// Creates a new Stripe price and payment link for the item.
  /// Returns the updated Item with the new payment link, or null if an error occurs.
  ///
  /// This is used when the dynamic pricing changes significantly and needs
  /// to be reflected in the backend and payment system.
  static Future<Item?> updateItemPrice(double newPrice) async {
    try {
      print(
        '[ItemApiService] Updating item price to \$${newPrice.toStringAsFixed(2)}',
      );

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/item/price'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'price': newPrice}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update price: ${response.statusCode} ${response.body}',
        );
      }

      final jsonData = jsonDecode(response.body);

      if (jsonData['items'] == null || jsonData['items'].isEmpty) {
        print('[ItemApiService] No item data in update response');
        return null;
      }

      // Parse the updated item
      final updatedItemData = jsonData['items'][0];
      return _parseItemFromBackend(updatedItemData, isSold: false);
    } catch (e) {
      print('[ItemApiService] Error updating price: $e');
      return null;
    }
  }

  /// Call the return endpoint to cancel a test purchase
  /// Returns true if return was successful, false otherwise
  static Future<bool> returnItem() async {
    try {
      print('[ItemApiService] Calling return endpoint');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/return'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('[ItemApiService] Item returned successfully');
        return true;
      } else {
        print(
          '[ItemApiService] Return failed: ${response.statusCode} ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('[ItemApiService] Error returning item: $e');
      return false;
    }
  }
}
