import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/hive_service.dart';
import '../models/favorite_item.dart';

enum FavoritesStatus { initial, loading, loaded, error }

/// ViewModel for the Favorites feature.
///
/// Uses Hive as a write-through cache: the in-memory list, the Hive box and
/// the remote API are kept in sync. Reads prefer the cache (O(1) membership
/// tests, instant screen paint), remote calls refresh it in the background.
class FavoritesViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  FavoritesStatus _status = FavoritesStatus.initial;
  List<FavoriteItem> _favorites = [];
  String? _errorMessage;

  FavoritesViewModel() {
    // Seed from cache so `isFavorited` works before the first API call.
    _favorites = HiveService.getFavorites().where((l) => !l.isSold).toList();
    if (_favorites.isNotEmpty) {
      _status = FavoritesStatus.loaded;
    }
  }

  FavoritesStatus get status => _status;
  List<FavoriteItem> get favorites => List.unmodifiable(_favorites);
  String? get errorMessage => _errorMessage;

  /// True if [productId] is favorited, checked against the in-memory list
  /// (which mirrors the Hive box).
  bool isFavorited(String productId) =>
      _favorites.any((f) => f.id == productId);

  /// Loads favorites. Emits cached results immediately, then fetches
  /// the authoritative list from the API and replaces the cache.
  Future<void> loadFavorites() async {
    // If we have nothing cached, show a spinner; otherwise keep current UI.
    if (_favorites.isEmpty) {
      _status = FavoritesStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fresh = await _apiService.getFavorites();
      _favorites = fresh;
      await HiveService.replaceFavorites(fresh);
      _status = FavoritesStatus.loaded;
    } catch (_) {
      // On failure, keep the cached list — that's the whole point of caching.
      if (_favorites.isEmpty) {
        _errorMessage = 'Could not load favorites. Please try again.';
        _status = FavoritesStatus.error;
      } else {
        _status = FavoritesStatus.loaded;
      }
    }

    notifyListeners();
  }

  /// Optimistically adds [item] to the cache + local list, then calls the API.
  /// If the network call fails (offline), queues the action for later sync
  /// instead of rolling back the optimistic update.
  Future<bool> addFavorite(FavoriteItem item) async {
    if (item.id == null) return false;
    if (_favorites.any((f) => f.id == item.id)) return true;

    // Optimistic update — show the heart immediately.
    _favorites = [..._favorites, item];
    await HiveService.putFavorite(item);
    // Remove any previous 'remove' intent so the latest action wins.
    await HiveService.removePendingFavorite(item.id!);
    notifyListeners();

    try {
      final success = await _apiService.addFavorite(item.id!);
      if (!success) {
        // Server rejected — roll back.
        _favorites = _favorites.where((f) => f.id != item.id).toList();
        await HiveService.removeFavorite(item.id!);
        notifyListeners();
      }
      return success;
    } catch (_) {
      // Network unavailable — keep the optimistic state and queue for sync.
      await HiveService.enqueuePendingFavorite(item.id!, 'add');
      return true; // treat as success from the user's perspective
    }
  }

  /// Drop every cached favorite from memory. Disk cleanup is the auth
  /// service's responsibility — this only handles the in-memory side.
  void resetForLogout() {
    _status = FavoritesStatus.initial;
    _errorMessage = null;
    _favorites = const [];
    notifyListeners();
  }

  /// Optimistically removes [productId] from the cache + local list, then
  /// calls the API. If the network call fails (offline), queues the action
  /// for later sync instead of rolling back.
  Future<bool> removeFavorite(String productId) async {
    final snapshot = List<FavoriteItem>.from(_favorites);

    // Optimistic update — remove the heart immediately.
    _favorites = _favorites.where((f) => f.id != productId).toList();
    await HiveService.removeFavorite(productId);
    // Remove any previous 'add' intent so the latest action wins.
    await HiveService.removePendingFavorite(productId);
    notifyListeners();

    try {
      final success = await _apiService.removeFavorite(productId);
      if (!success) {
        // Server rejected — roll back.
        _favorites = snapshot;
        final removed = snapshot.firstWhere((f) => f.id == productId);
        await HiveService.putFavorite(removed);
        notifyListeners();
      }
      return success;
    } catch (_) {
      // Network unavailable — keep the optimistic state and queue for sync.
      await HiveService.enqueuePendingFavorite(productId, 'remove');
      return true; // treat as success from the user's perspective
    }
  }
}
