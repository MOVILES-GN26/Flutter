import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/listing.dart';

enum HomeStatus { initial, loading, loaded, error }

/// Describes where the "Recommended for you" data came from.
enum RecommendedSource { none, network, cache, localStorage }

/// ViewModel for the Home screen.
///
/// Strategy: stale-while-revalidate.
///   1. Emit whatever Hive has cached synchronously → screen paints instantly.
///   2. Kick off the API call in parallel and, when it returns, replace
///      both the in-memory state and the Hive snapshot.
class HomeViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  HomeStatus _status = HomeStatus.initial;
  List<Listing> _recentlyAddedItems = [];
  List<String> _trendingCategories = [];
  List<Listing> _recommendedItems = [];
  RecommendedSource _recommendedSource = RecommendedSource.none;
  String? _errorMessage;

  HomeViewModel() {
    _recentlyAddedItems = HiveService.getRecentListings()
        .where((l) => !l.isSold)
        .toList();
    _trendingCategories = HiveService.getTrendingCategories();
    // Seed recommended from Hive so the section is visible before the first
    // network response.
    final cached = HiveService.getRecommendedListings()
        .where((l) => !l.isSold)
        .toList();
    if (cached.isNotEmpty) {
      _recommendedItems = cached;
      _recommendedSource = RecommendedSource.cache;
    }
    if (_recentlyAddedItems.isNotEmpty || _trendingCategories.isNotEmpty) {
      _status = HomeStatus.loaded;
    }
  }

  HomeStatus get status => _status;
  List<Listing> get recentlyAddedItems =>
      List.unmodifiable(_recentlyAddedItems);
  List<String> get trendingCategories =>
      List.unmodifiable(_trendingCategories);
  List<Listing> get recommendedItems =>
      List.unmodifiable(_recommendedItems);
  RecommendedSource get recommendedSource => _recommendedSource;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdatedAt => HiveService.recentListingsUpdatedAt;

  /// The [limit] products the user most recently opened, newest first.
  /// Backed by the sqflite `recent_views` table joined against `listings`.
  Future<List<Listing>> getRecentlyViewed({int limit = 10}) =>
      LocalDbService.getRecentlyViewed(limit: limit);

  /// Drop every piece of in-memory state tied to the prior session so the
  /// next user does not briefly see the previous account's feed before
  /// [loadHomeData] refetches.
  void resetForLogout() {
    _status = HomeStatus.initial;
    _errorMessage = null;
    _recentlyAddedItems = const [];
    _trendingCategories = const [];
    _recommendedItems = const [];
    _recommendedSource = RecommendedSource.none;
    notifyListeners();
  }

  /// Load recent products and trending categories in parallel.
  /// Cached results remain visible until the fresh ones arrive.
  Future<void> loadHomeData() async {
    if (_recentlyAddedItems.isEmpty && _trendingCategories.isEmpty) {
      _status = HomeStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final productsF = _apiService.getRecentProducts();
      final trendingF = _apiService.getTrendingCategories();
      final recommendedF = _apiService.getRecommendedProducts();
      final items = await productsF;
      final trending = await trendingF;
      final recommended = await recommendedF;

      _recentlyAddedItems = items;
      _trendingCategories = trending;
      _recommendedItems = recommended.items;
      _recommendedSource = recommended.items.isEmpty
          ? RecommendedSource.none
          : recommended.fromCache
              ? RecommendedSource.cache
              : RecommendedSource.network;
      _status = HomeStatus.loaded;

      // Fire-and-forget cache writes — the UI already has the data.
      HiveService.putRecentListings(items);
      HiveService.putTrendingCategories(trending);
    } catch (_) {
      if (_recentlyAddedItems.isEmpty && _trendingCategories.isEmpty) {
        _errorMessage = 'Could not load items. Please try again.';
        _status = HomeStatus.error;
      } else {
        _status = HomeStatus.loaded;
      }
    }

    notifyListeners();
  }
}
