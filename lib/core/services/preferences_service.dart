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
