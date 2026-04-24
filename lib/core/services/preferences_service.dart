import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable theme preference.
/// [auto] respects the time-of-day rule inside [ThemeViewModel].
enum ThemePreference { auto, light, dark }

/// Singleton wrapper around [SharedPreferences] for non-sensitive settings.
///
/// Call [PreferencesService.init] once at app startup (in `main`) before
/// accessing [PreferencesService.instance].
class PreferencesService {
  PreferencesService._(this._prefs);

  static PreferencesService? _instance;
  final SharedPreferences _prefs;

  // ── Keys ──────────────────────────────────────────────────────────────
  static const String _kThemePreference = 'theme_preference';
  static const String _kOnboardingCompleted = 'onboarding_completed';
  static const String _kLastCatalogCategory = 'last_catalog_category';
  static const String _kLastCatalogCondition = 'last_catalog_condition';
  static const String _kLastCatalogPriceSort = 'last_catalog_price_sort';
  static const String _kDefaultStoreId = 'default_store_id';
  static const String _kLastKnownLat = 'last_known_lat';
  static const String _kLastKnownLng = 'last_known_lng';
  static const String _kLastKnownLocationAt = 'last_known_location_at';

  /// Initialize the singleton. Safe to call multiple times.
  static Future<void> init() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    _instance = PreferencesService._(prefs);
  }

  static PreferencesService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'PreferencesService not initialized. Call PreferencesService.init() in main() before runApp().',
      );
    }
    return i;
  }

  // ── Theme ─────────────────────────────────────────────────────────────

  ThemePreference get themePreference {
    final value = _prefs.getString(_kThemePreference);
    return ThemePreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ThemePreference.auto,
    );
  }

  Future<void> setThemePreference(ThemePreference pref) {
    return _prefs.setString(_kThemePreference, pref.name);
  }

  // ── Onboarding ────────────────────────────────────────────────────────

  bool get onboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool value) {
    return _prefs.setBool(_kOnboardingCompleted, value);
  }

  // ── Catalog filters ───────────────────────────────────────────────────

  String? get lastCatalogCategory => _prefs.getString(_kLastCatalogCategory);
  String? get lastCatalogCondition => _prefs.getString(_kLastCatalogCondition);
  String? get lastCatalogPriceSort => _prefs.getString(_kLastCatalogPriceSort);

  Future<void> setLastCatalogFilters({
    String? category,
    String? condition,
    String? priceSort,
  }) async {
    await _writeOrRemove(_kLastCatalogCategory, category);
    await _writeOrRemove(_kLastCatalogCondition, condition);
    await _writeOrRemove(_kLastCatalogPriceSort, priceSort);
  }

  // ── Default "Post as" store ───────────────────────────────────────────

  String? get defaultStoreId => _prefs.getString(_kDefaultStoreId);

  Future<void> setDefaultStoreId(String? storeId) =>
      _writeOrRemove(_kDefaultStoreId, storeId);

  // ── Last known GPS location ───────────────────────────────────────────
  //
  // Device-scoped (the phone is the phone regardless of the user), so it
  // survives logout. Used by [LocationService] as a fallback when a fresh
  // GPS fix is not available — e.g. indoors, weak signal, or offline at
  // cold start.

  /// Last cached GPS fix, or null if we've never stored one. Returns null
  /// if any piece (lat/lng/timestamp) is missing so callers can branch
  /// cleanly without juggling three nullable keys.
  CachedLocation? get lastKnownLocation {
    final lat = _prefs.getDouble(_kLastKnownLat);
    final lng = _prefs.getDouble(_kLastKnownLng);
    final iso = _prefs.getString(_kLastKnownLocationAt);
    if (lat == null || lng == null || iso == null) return null;
    final ts = DateTime.tryParse(iso);
    if (ts == null) return null;
    return CachedLocation(latitude: lat, longitude: lng, timestamp: ts);
  }

  Future<void> setLastKnownLocation({
    required double latitude,
    required double longitude,
  }) async {
    await Future.wait([
      _prefs.setDouble(_kLastKnownLat, latitude),
      _prefs.setDouble(_kLastKnownLng, longitude),
      _prefs.setString(
        _kLastKnownLocationAt,
        DateTime.now().toIso8601String(),
      ),
    ]);
  }

  // ── Session cleanup ───────────────────────────────────────────────────

  /// Clears preferences that belong to the logged-in user:
  ///   * last-used catalog filters (could reveal prior user's browsing)
  ///   * default "post as" store id (tied to the user's stores)
  ///
  /// Device-scoped preferences — theme mode, onboarding completion — are
  /// deliberately preserved across account changes.
  Future<void> clearUserScoped() async {
    await Future.wait([
      _prefs.remove(_kLastCatalogCategory),
      _prefs.remove(_kLastCatalogCondition),
      _prefs.remove(_kLastCatalogPriceSort),
      _prefs.remove(_kDefaultStoreId),
    ]);
  }

  // ── Internal helpers ──────────────────────────────────────────────────

  Future<void> _writeOrRemove(String key, String? value) {
    if (value == null || value.isEmpty) {
      return _prefs.remove(key);
    }
    return _prefs.setString(key, value);
  }

  /// Wipes all non-sensitive preferences. Does NOT touch secure storage.
  Future<void> clear() => _prefs.clear();
}

/// Immutable snapshot of a GPS fix we stored in prefs as a fallback for
/// when [LocationService] can't get a fresh one.
class CachedLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const CachedLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Duration get age => DateTime.now().difference(timestamp);
}

