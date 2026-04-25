import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/listing.dart';

enum HomeStatus { initial, loading, loaded, error }

/// ViewModel para la pantalla de Home
class HomeViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  HomeStatus _status = HomeStatus.initial;
  List<Listing> _recentlyAddedItems = [];
  List<String> _trendingCategories = [];
  String? _errorMessage;

  HomeStatus get status => _status;
  List<Listing> get recentlyAddedItems => List.unmodifiable(_recentlyAddedItems);
  List<String> get trendingCategories => List.unmodifiable(_trendingCategories);
  String? get errorMessage => _errorMessage;

  /// Load recent products and trending categories in parallel.
  Future<void> loadHomeData() async {
    _status = HomeStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final productsF = _apiService.getRecentProducts();
      final trendingF = _apiService.getTrendingCategories();
      _recentlyAddedItems = await productsF;
      _trendingCategories = await trendingF;

      // Hide products that already have a payment_uploaded order from the buyer
      try {
        final pendingOrders =
            await StorageService().getPendingPaymentOrders();
        if (pendingOrders.isNotEmpty) {
          final pendingIds = pendingOrders.keys.toSet();
          _recentlyAddedItems = _recentlyAddedItems
              .where((p) => p.id == null || !pendingIds.contains(p.id))
              .toList();
        }
      } catch (_) {}

      _status = HomeStatus.loaded;
    } catch (e) {
      _errorMessage = 'Could not load items. Please try again.';
      _status = HomeStatus.error;
    }

    notifyListeners();
  }
}
