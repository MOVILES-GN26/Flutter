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

  /// LRU cache for trending-category lookups.
  /// `sortedCategories` uses `contains()` which is O(n) on each rebuild;
  /// this LRU converts repeated lookups to O(1).
  ///
  /// | Instance       | K             | V    | maxSize | Why LRU here                                  |
  /// |----------------|---------------|------|---------|-----------------------------------------------|
  /// | trendingLookup | String (query) | bool | 20      | sortedCategories recalculates contains() each |
  /// |                |               |      |         | rebuild; LRU RAM avoids the linear scan       |
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

  /// True when the active location came from a live GPS fix. False when we
  /// fell back to a persisted fix — the UI can use this to add a discrete
  /// "last known location" hint.
  bool get locationIsFresh => _locationIsFresh;

  /// When the fallback fix was captured, or null if the location is fresh
  /// or unavailable.
  DateTime? get locationCachedAt => _locationCachedAt;

  /// Categories sorted by trending (most searched first), rest appended.
  /// Uses [_trendingLookup] LRU to avoid O(n) `contains()` on every rebuild.
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

  /// Detect the user's location and determine which campus building
  /// they are closest to. Call once when the catalog screen loads.
  ///
  /// Offline-first: uses [LocationService.resolvePosition] which tries a
  /// fresh GPS fix first, then falls back to the last cached one (<24h).
  /// If both fail, [locationLoaded] still becomes true and the UI simply
  /// hides the "nearby" section — no error, no spinner.
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

  /// Fetch products and trending categories in parallel.
  ///
  /// Stale-while-revalidate against sqflite:
  ///   1. Run the same filter query against the local cache and emit those
  ///      results immediately so the list paints without network latency.
  ///   2. Hit the API. On success, replace the in-memory list and UPSERT
  ///      every listing into the cache. On failure, keep the cached data
  ///      and surface an error only if the cache was empty.
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

  /// Fire-and-forget: we don't await because the current filter state is
  /// already in memory and the UI doesn't need to wait on disk I/O.
  void _persistFilters() {
    PreferencesService.instance.setLastCatalogFilters(
      category: _selectedCategory,
      condition: _selectedCondition,
      priceSort: _selectedPriceSort,
    );
  }

  /// Wipes filters, products, and trending state so the next account does
  /// not inherit the previous user's search/filter UI. Geolocation-derived
  /// fields (nearest building, nearby buildings) are device-scoped and
  /// survive on purpose.
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
