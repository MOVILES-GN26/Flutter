import 'package:flutter/foundation.dart';
import '../../../core/cache/lru_cache.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/constants/post_categories.dart';

export '../../../core/constants/post_conditions.dart';

enum CatalogStatus { initial, loading, loaded, error }

/// Possible price sort options sent to the API.
const List<String> priceSortOptions = ['Lowest Price', 'Highest Price'];

/// ViewModel for the Catalog / product list screen.
class CatalogViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  CatalogStatus _status = CatalogStatus.initial;
  List<Listing> _products = [];
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedCondition;
  String? _selectedPriceSort;

  CatalogViewModel() {
    // Restore the user's last-used filters from disk so the catalog screen
    // opens pre-filtered exactly as they left it on the previous session.
    final prefs = PreferencesService.instance;
    _selectedCategory = prefs.lastCatalogCategory;
    _selectedCondition = prefs.lastCatalogCondition;
    _selectedPriceSort = prefs.lastCatalogPriceSort;
  }

  // ── Trending state ──
  List<String> _trendingCategories = [];

  final LruCache<String, bool> _trendingLookup = LruCache(maxSize: 20);

  // ── Location state ──
  String? _nearestBuilding;
  List<String> _nearbyBuildings = [];
  List<Listing> _nearbyProducts = [];
  bool _locationLoaded = false;
  bool _isOnCampus = false;
  bool _locationIsFresh = true;
  DateTime? _locationCachedAt;

  CatalogStatus get status => _status;
  List<Listing> get products => List.unmodifiable(_products);
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedCondition => _selectedCondition;
  String? get selectedPriceSort => _selectedPriceSort;

  String? get nearestBuilding => _nearestBuilding;
  List<String> get nearbyBuildings => List.unmodifiable(_nearbyBuildings);
  List<Listing> get nearbyProducts => List.unmodifiable(_nearbyProducts);
  bool get locationLoaded => _locationLoaded;
  bool get isOnCampus => _isOnCampus;

  bool get locationIsFresh => _locationIsFresh;

  DateTime? get locationCachedAt => _locationCachedAt;

  List<String> get sortedCategories {
    if (_trendingCategories.isEmpty) return postCategories;
    final trending = _trendingCategories.where((c) {
      final cached = _trendingLookup.get(c);
      if (cached != null) return cached;
      final isTrending = postCategories.contains(c);
      _trendingLookup.put(c, isTrending);
      return isTrending;
    }).toList();
    final rest = postCategories.where((c) {
      final cached = _trendingLookup.get('!$c');
      if (cached != null) return cached;
      final isNotTrending = !_trendingCategories.contains(c);
      _trendingLookup.put('!$c', isNotTrending);
      return isNotTrending;
    }).toList();
    return [...trending, ...rest];
  }

  /// Fetch trending categories and update sort order. Fire-and-forget on init.
  Future<void> loadTrending() async {
    try {
      _trendingCategories = await _apiService.getTrendingCategories();
      _trendingLookup.clear(); // invalidate stale lookup entries
      notifyListeners();
    } catch (_) {}
  }

  Future<void> detectLocation() async {
    final resolved = await _locationService.resolvePosition();
    if (resolved == null) {
      _locationLoaded = true;
      _locationIsFresh = true;
      _locationCachedAt = null;
      notifyListeners();
      return;
    }

    _isOnCampus = _locationService.isOnCampusAt(
      resolved.latitude,
      resolved.longitude,
    );
    _nearestBuilding = _locationService.getNearestBuildingAt(
      resolved.latitude,
      resolved.longitude,
    );
    _nearbyBuildings = _locationService.getNearbyBuildingsAt(
      resolved.latitude,
      resolved.longitude,
    );
    _locationLoaded = true;
    _locationIsFresh = resolved.isFresh;
    _locationCachedAt = resolved.cachedAt;

    _partitionNearbyProducts();
    notifyListeners();
  }

  /// Partition already-loaded products into nearby vs. all.
  void _partitionNearbyProducts() {
    if (_nearbyBuildings.isEmpty) {
      _nearbyProducts = [];
      return;
    }
    _nearbyProducts = _products
        .where((p) => _nearbyBuildings.contains(p.buildingLocation))
        .toList();
  }

  Future<void> loadProducts() async {
    // ── 1. Cached results first ──
    final cached = await LocalDbService.queryListings(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      category: _selectedCategory,
      condition: _selectedCondition,
      priceSort: _selectedPriceSort,
    );
    if (cached.isNotEmpty) {
      _products = cached;
      _partitionNearbyProducts();
      _status = CatalogStatus.loaded;
      notifyListeners();
    } else {
      _status = CatalogStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    // ── 2. Refresh from API ──
    try {
      final results = await Future.wait([
        _apiService.getProducts(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          category: _selectedCategory,
          condition: _selectedCondition,
          priceSort: _selectedPriceSort,
        ),
        if (_trendingCategories.isEmpty) _apiService.getTrendingCategories(),
      ]);

      _products = (results[0] as List<Map<String, dynamic>>)
          .map((json) => Listing.fromJson(json))
          .toList();

      if (_trendingCategories.isEmpty) {
        _trendingCategories = results[1] as List<String>;
      }

      _partitionNearbyProducts();
      _status = CatalogStatus.loaded;

      // Fire-and-forget: UI already has the data in memory.
      LocalDbService.upsertListings(_products);
    } catch (_) {
      if (_products.isEmpty) {
        _errorMessage =
            'Unable to load products. Please check your connection and try again.';
        _status = CatalogStatus.error;
      } else {
        _status = CatalogStatus.loaded;
      }
    }

    notifyListeners();
  }

  /// Update search query and reload. Persists non-empty queries to the
  /// local search history so the search bar can show recent terms.
  void setSearchQuery(String query) {
    _searchQuery = query;
    if (query.trim().isNotEmpty) {
      LocalDbService.recordSearch(query);
    }
    loadProducts();
  }

  /// Last [limit] distinct search terms the user has typed, newest first.
  Future<List<String>> getRecentSearches({int limit = 5}) =>
      LocalDbService.getRecentSearches(limit: limit);

  /// Toggle a category filter. Pass null to clear.
  void setCategory(String? category) {
    _selectedCategory = (_selectedCategory == category) ? null : category;
    _persistFilters();
    loadProducts();
  }

  /// Toggle a condition filter. Pass null to clear.
  void setCondition(String? condition) {
    _selectedCondition =
        (_selectedCondition == condition) ? null : condition;
    _persistFilters();
    loadProducts();
  }

  /// Set price sort. Pass null to clear.
  void setPriceSort(String? sort) {
    _selectedPriceSort = (_selectedPriceSort == sort) ? null : sort;
    _persistFilters();
    loadProducts();
  }

  /// Apply multiple filters at once (avoids redundant API calls).
  void applyFilters({
    String? category,
    String? priceSort,
    String? condition,
  }) {
    _selectedCategory = category;
    _selectedPriceSort = priceSort;
    _selectedCondition = condition;
    _persistFilters();
    loadProducts();
  }

  /// Persists the current filter selection. Fire-and-forget by design —
  /// the UI already reflects the change, so we don't block on disk I/O.
  ///
  /// ## Why handler-style (.then/.catchError) here instead of async/await?
  ///
  /// This method returns `void` and has no caller that cares about
  /// completion. Using `async` would force us to make the method
  /// `Future<void>` (no caller awaits it) or suppress the `unawaited_futures`
  /// lint. The imperative `.then/.catchError` chain is the idiomatic Dart
  /// way of saying "I don't care when this finishes, but I do want errors
  /// logged, not silently swallowed."
  void _persistFilters() {
    PreferencesService.instance
        .setLastCatalogFilters(
          category: _selectedCategory,
          condition: _selectedCondition,
          priceSort: _selectedPriceSort,
        )
        .then((_) => debugPrint('[Catalog] filters persisted'))
        .catchError(
          (Object err) =>
              debugPrint('[Catalog] filter persistence failed: $err'),
        );
  }

  void resetForLogout() {
    _status = CatalogStatus.initial;
    _errorMessage = null;
    _products = const [];
    _nearbyProducts = const [];
    _trendingCategories = const [];
    _searchQuery = '';
    _selectedCategory = null;
    _selectedCondition = null;
    _selectedPriceSort = null;
    notifyListeners();
  }
}
