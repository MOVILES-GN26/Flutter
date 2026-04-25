import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
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

  // ── Trending state ──
  List<String> _trendingCategories = [];

  // ── Location state ──
  String? _nearestBuilding;
  List<String> _nearbyBuildings = [];
  List<Listing> _nearbyProducts = [];
  bool _locationLoaded = false;
  bool _isOnCampus = false;

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

  /// Categories sorted by trending (most searched first), rest appended.
  List<String> get sortedCategories {
    if (_trendingCategories.isEmpty) return postCategories;
    final trending = _trendingCategories.where(postCategories.contains).toList();
    final rest = postCategories.where((c) => !_trendingCategories.contains(c)).toList();
    return [...trending, ...rest];
  }

  /// Fetch trending categories and update sort order. Fire-and-forget on init.
  Future<void> loadTrending() async {
    try {
      _trendingCategories = await _apiService.getTrendingCategories();
      notifyListeners();
    } catch (_) {}
  }

  /// Detect the user's location and determine which campus building
  /// they are closest to. Call once when the catalog screen loads.
  Future<void> detectLocation() async {
    final Position? position = await _locationService.getCurrentPosition();
    if (position == null) {
      _locationLoaded = true;
      notifyListeners();
      return;
    }

    _isOnCampus = _locationService.isOnCampus(position);
    _nearestBuilding = _locationService.getNearestBuilding(position);
    _nearbyBuildings = _locationService.getNearbyBuildings(position);
    _locationLoaded = true;

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
  /// Both complete before notifyListeners() is called, so the category
  /// strip always renders already sorted by popularity.
  Future<void> loadProducts() async {
    _status = CatalogStatus.loading;
    _errorMessage = null;
    notifyListeners();

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

      // Hide products that already have a payment_uploaded order from this buyer
      try {
        final pendingOrders =
            await StorageService().getPendingPaymentOrders();
        if (pendingOrders.isNotEmpty) {
          final pendingIds = pendingOrders.keys.toSet();
          _products = _products
              .where((p) => p.id == null || !pendingIds.contains(p.id))
              .toList();
        }
      } catch (_) {}

      if (_trendingCategories.isEmpty) {
        _trendingCategories = results[1] as List<String>;
      }

      _partitionNearbyProducts();
      _status = CatalogStatus.loaded;
    } catch (e) {
      _errorMessage =
          'Unable to load products. Please check your connection and try again.';
      _status = CatalogStatus.error;
    }

    notifyListeners();
  }

  /// Update search query and reload.
  void setSearchQuery(String query) {
    _searchQuery = query;
    loadProducts();
  }

  /// Toggle a category filter. Pass null to clear.
  void setCategory(String? category) {
    _selectedCategory = (_selectedCategory == category) ? null : category;
    loadProducts();
  }

  /// Toggle a condition filter. Pass null to clear.
  void setCondition(String? condition) {
    _selectedCondition =
        (_selectedCondition == condition) ? null : condition;
    loadProducts();
  }

  /// Set price sort. Pass null to clear.
  void setPriceSort(String? sort) {
    _selectedPriceSort = (_selectedPriceSort == sort) ? null : sort;
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
    loadProducts();
  }
}
