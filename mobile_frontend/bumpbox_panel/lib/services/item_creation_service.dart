import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Service for creating items via backend API
class ItemCreationService {
  /// Create a new item listing
  ///
  /// Returns a map containing:
  /// - itemId: Database ID of created item
  /// - paymentLink: Stripe payment link URL
  static Future<Map<String, dynamic>> createItem({
    required String phone,
    required String itemName,
    required String description,
    required double price,
    required int days,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.createItemUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'item_name': itemName,
          'description': description,
          'price': price,
          'days': days,
        }),
      );

      if (response.statusCode != 201) {
        final errorBody = response.body;
        throw Exception(
          'Failed to create item: ${response.statusCode} - $errorBody',
        );
      }

      final data = jsonDecode(response.body);

      if (data['message'] != 'Item created successfully') {
        throw Exception('Unexpected response from backend: ${data['message']}');
      }

      return {
        'itemId': data['itemId'],
        'paymentLink': data['data']?['paymentLink'] ?? '',
        'productId': data['data']?['productId'] ?? '',
        'priceId': data['data']?['priceId'] ?? '',
      };
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to create item: $e');
    }
  }

  /// Validate phone number format (Singapore +65 format)
  static bool isValidPhoneNumber(String phone) {
    // Remove spaces and dashes
    final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');

    // Singapore phone: 8 digits, optionally with +65 prefix
    if (cleaned.startsWith('+65')) {
      return cleaned.length == 11 &&
          RegExp(r'^\+65[0-9]{8}$').hasMatch(cleaned);
    } else if (cleaned.startsWith('65')) {
      return cleaned.length == 10 && RegExp(r'^65[0-9]{8}$').hasMatch(cleaned);
    } else {
      return cleaned.length == 8 && RegExp(r'^[0-9]{8}$').hasMatch(cleaned);
    }
  }

  /// Format phone number to include +65 prefix if not present
  static String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');

    if (cleaned.startsWith('+65')) {
      return cleaned;
    } else if (cleaned.startsWith('65')) {
      return '+$cleaned';
    } else {
      return '+65$cleaned';
    }
  }
}
