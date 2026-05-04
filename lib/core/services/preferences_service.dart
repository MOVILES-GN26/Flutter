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

  // Post text-draft (battery-triggered auto-save) keys
  static const String _kPostDraftTitle = 'post_draft_title';
  static const String _kPostDraftDescription = 'post_draft_description';
  static const String _kPostDraftCategory = 'post_draft_category';
  static const String _kPostDraftBuilding = 'post_draft_building';
  static const String _kPostDraftPrice = 'post_draft_price';
  static const String _kPostDraftCondition = 'post_draft_condition';
  static const String _kPostDraftSavedAt = 'post_draft_saved_at';

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

  // ── Post text draft (battery-triggered auto-save) ─────────────────────

  /// Returns true if a non-empty draft is currently stored.
  bool get hasPostDraft => _prefs.containsKey(_kPostDraftTitle);

  /// Returns the last saved draft fields.  Callers should check [hasPostDraft]
  /// before calling this; all values may be null if no draft exists.
  Map<String, String?> loadPostDraft() => {
        'title': _prefs.getString(_kPostDraftTitle),
        'description': _prefs.getString(_kPostDraftDescription),
        'category': _prefs.getString(_kPostDraftCategory),
        'building': _prefs.getString(_kPostDraftBuilding),
        'price': _prefs.getString(_kPostDraftPrice),
        'condition': _prefs.getString(_kPostDraftCondition),
        'savedAt': _prefs.getString(_kPostDraftSavedAt),
      };

  Future<void> savePostDraft({
    required String title,
    required String description,
    required String category,
    required String building,
    required String price,
    required String condition,
  }) async {
    await Future.wait([
      _prefs.setString(_kPostDraftTitle, title),
      _prefs.setString(_kPostDraftDescription, description),
      _prefs.setString(_kPostDraftCategory, category),
      _prefs.setString(_kPostDraftBuilding, building),
      _prefs.setString(_kPostDraftPrice, price),
      _prefs.setString(_kPostDraftCondition, condition),
      _prefs.setString(
          _kPostDraftSavedAt, DateTime.now().toIso8601String()),
    ]);
  }

  Future<void> clearPostDraft() => Future.wait([
        _prefs.remove(_kPostDraftTitle),
        _prefs.remove(_kPostDraftDescription),
        _prefs.remove(_kPostDraftCategory),
        _prefs.remove(_kPostDraftBuilding),
        _prefs.remove(_kPostDraftPrice),
        _prefs.remove(_kPostDraftCondition),
        _prefs.remove(_kPostDraftSavedAt),
      ]);

  // ── Session cleanup ───────────────────────────────────────────────────

  /// Clears preferences that belong to the logged-in user:
  ///   * last-used catalog filters (could reveal prior user's browsing)
  ///   * default "post as" store id (tied to the user's stores)
  ///   * any in-progress post draft
  ///
  /// Device-scoped preferences — theme mode, onboarding completion — are
  /// deliberately preserved across account changes.
  Future<void> clearUserScoped() async {
    await Future.wait([
      _prefs.remove(_kLastCatalogCategory),
      _prefs.remove(_kLastCatalogCondition),
      _prefs.remove(_kLastCatalogPriceSort),
      _prefs.remove(_kDefaultStoreId),
      clearPostDraft(),
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

