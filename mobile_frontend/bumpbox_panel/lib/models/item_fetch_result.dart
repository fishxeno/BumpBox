import 'item.dart';

/// Result of fetching an item from the backend API
///
/// Distinguishes between different states:
/// - itemAvailable: Item exists and is available for purchase
/// - emptyLocker: Backend confirmed the locker is empty (sold with specific message)
/// - error: Error occurred during fetch
class ItemFetchResult {
  final ItemFetchStatus status;
  final Item? item;
  final String? message;

  ItemFetchResult._({required this.status, this.item, this.message});

  /// Item is available for purchase
  factory ItemFetchResult.available(Item item) {
    return ItemFetchResult._(status: ItemFetchStatus.itemAvailable, item: item);
  }

  /// Backend confirmed locker is empty (item fully sold)
  factory ItemFetchResult.emptyLocker() {
    return ItemFetchResult._(
      status: ItemFetchStatus.emptyLocker,
      message: 'Item is sold with status sold',
    );
  }

  /// Error occurred during fetch
  factory ItemFetchResult.error(String message) {
    return ItemFetchResult._(status: ItemFetchStatus.error, message: message);
  }

  bool get isAvailable => status == ItemFetchStatus.itemAvailable;
  bool get isEmpty => status == ItemFetchStatus.emptyLocker;
  bool get isError => status == ItemFetchStatus.error;
}

enum ItemFetchStatus { itemAvailable, emptyLocker, error }
