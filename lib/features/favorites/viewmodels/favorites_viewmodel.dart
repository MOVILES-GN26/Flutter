import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/favorite_item.dart';

enum FavoritesStatus { initial, loading, loaded, error }

/// ViewModel for the Favorites feature.
class FavoritesViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  FavoritesStatus _status = FavoritesStatus.initial;
  List<FavoriteItem> _favorites = [];
  String? _errorMessage;

  FavoritesStatus get status => _status;
  List<FavoriteItem> get favorites => List.unmodifiable(_favorites);
  String? get errorMessage => _errorMessage;

  /// Returns true if the product with [productId] is in the current
  /// in-memory favorites list.
  bool isFavorited(String productId) =>
      _favorites.any((f) => f.id == productId);

  /// Loads all favorites from the API.
  Future<void> loadFavorites() async {
    _status = FavoritesStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _favorites = await _apiService.getFavorites();
      _status = FavoritesStatus.loaded;
    } catch (_) {
      _errorMessage = 'Could not load favorites. Please try again.';
      _status = FavoritesStatus.error;
    }

    notifyListeners();
  }

  /// Optimistically adds [item] to the local list, then calls the API.
  /// Rolls back the local change if the API call fails.
  Future<bool> addFavorite(FavoriteItem item) async {
    if (item.id == null) return false;
    if (_favorites.any((f) => f.id == item.id)) return true;

    _favorites = [..._favorites, item];
    notifyListeners();

    final success = await _apiService.addFavorite(item.id!);
    if (!success) {
      _favorites = _favorites.where((f) => f.id != item.id).toList();
      notifyListeners();
    }
    return success;
  }

  /// Optimistically removes [productId] from the local list, then calls the API.
  /// Rolls back the local change if the API call fails.
  Future<bool> removeFavorite(String productId) async {
    final snapshot = List<FavoriteItem>.from(_favorites);
    _favorites = _favorites.where((f) => f.id != productId).toList();
    notifyListeners();

    final success = await _apiService.removeFavorite(productId);
    if (!success) {
      _favorites = snapshot;
      notifyListeners();
    }
    return success;
  }
}
