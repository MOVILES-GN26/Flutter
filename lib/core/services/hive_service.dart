import 'package:hive_flutter/hive_flutter.dart';
import '../models/listing.dart';
import '../models/pending_post.dart';
import '../../features/auth/models/auth_user.dart';

/// Hive-backed key/value store for objects that need instantaneous access
/// across the app. Stores plain `Map<String, dynamic>` payloads so we can
/// rely on each model's existing `toJson`/`fromJson` and avoid code-gen.
///
/// Four boxes:
///   * [_favoritesBox]     — keyed by productId → listing JSON.
///   * [_userBox]          — single key 'current_user' → authUser JSON.
///   * [_homeBox]          — trending categories + most recent listings.
///   * [_pendingPostsBox]  — queue of posts awaiting network retry.
class HiveService {
  HiveService._();

  // ── Box names ─────────────────────────────────────────────────────────
  static const String _favoritesBox = 'favorites_box';
  static const String _userBox = 'user_box';
  static const String _homeBox = 'home_snapshot_box';
  static const String _pendingPostsBox = 'pending_posts_box';
  static const String _pendingViewsBox = 'pending_views_box';
  static const String _pendingContactsBox = 'pending_contacts_box';
  static const String _productStatsBox = 'product_stats_box';
  static const String _productOrdersBox = 'product_orders_box';
  static const String _pendingCategoryViewsBox = 'pending_category_views_box';

  // ── Keys inside single-slot boxes ─────────────────────────────────────
  static const String _kCurrentUser = 'current_user';
  static const String _kTrendingCategories = 'trending_categories';
  static const String _kRecentListings = 'recent_listings';
  static const String _kRecentListingsUpdatedAt = 'recent_listings_updated_at';
  static const String _kRecommendedListings = 'recommended_listings';
  static const String _kRecommendedListingsUpdatedAt = 'recommended_listings_updated_at';

  static const int _recentListingsMax = 20;

  /// Initialize Hive and open all required boxes. Call once in [main].
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(_favoritesBox),
      Hive.openBox(_userBox),
      Hive.openBox(_homeBox),
      Hive.openBox(_pendingPostsBox),
      Hive.openBox(_pendingViewsBox),
      Hive.openBox(_pendingContactsBox),
      Hive.openBox(_productStatsBox),
      Hive.openBox(_productOrdersBox),
      Hive.openBox(_pendingCategoryViewsBox),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Favorites
  // ══════════════════════════════════════════════════════════════════════

  static Box get _favs => Hive.box(_favoritesBox);

  static List<Listing> getFavorites() {
    return _favs.values
        .map((v) => Listing.fromJson(_asStringMap(v)))
        .toList();
  }

  static bool isFavorited(String productId) => _favs.containsKey(productId);

  static Future<void> putFavorite(Listing listing) async {
    if (listing.id == null) return;
    await _favs.put(listing.id, _listingToCacheable(listing));
  }

  static Future<void> removeFavorite(String productId) =>
      _favs.delete(productId);

  /// Replace the entire cached favorites list with [listings].
  /// Used after a full fetch from the API.
  static Future<void> replaceFavorites(List<Listing> listings) async {
    await _favs.clear();
    await _favs.putAll({
      for (final l in listings)
        if (l.id != null) l.id!: _listingToCacheable(l),
    });
  }

  static Future<void> clearFavorites() => _favs.clear();

  // ══════════════════════════════════════════════════════════════════════
  // User
  // ══════════════════════════════════════════════════════════════════════

  static Box get _user => Hive.box(_userBox);

  static AuthUser? getUser() {
    final raw = _user.get(_kCurrentUser);
    if (raw == null) return null;
    return AuthUser.fromJson(_asStringMap(raw));
  }

  static Future<void> putUser(AuthUser user) =>
      _user.put(_kCurrentUser, user.toJson());

  static Future<void> clearUser() => _user.delete(_kCurrentUser);

  // ══════════════════════════════════════════════════════════════════════
  // Home snapshot
  // ══════════════════════════════════════════════════════════════════════

  static Box get _home => Hive.box(_homeBox);

  static List<String> getTrendingCategories() {
    final raw = _home.get(_kTrendingCategories);
    if (raw is! List) return const [];
    return raw.cast<String>();
  }

  static Future<void> putTrendingCategories(List<String> categories) =>
      _home.put(_kTrendingCategories, categories);

  static List<Listing> getRecentListings() {
    final raw = _home.get(_kRecentListings);
    if (raw is! List) return const [];
    return raw.map((e) => Listing.fromJson(_asStringMap(e))).toList();
  }

  /// Stores the first [_recentListingsMax] listings and stamps the write time.
  static Future<void> putRecentListings(List<Listing> listings) async {
    final trimmed =
        listings.take(_recentListingsMax).map(_listingToCacheable).toList();
    await _home.put(_kRecentListings, trimmed);
    await _home.put(
      _kRecentListingsUpdatedAt,
      DateTime.now().toIso8601String(),
    );
  }

  /// When the home snapshot was last refreshed, if ever.
  static DateTime? get recentListingsUpdatedAt {
    final iso = _home.get(_kRecentListingsUpdatedAt);
    if (iso is! String) return null;
    return DateTime.tryParse(iso);
  }

  // ── Recommended listings ──────────────────────────────────────────────

  static List<Listing> getRecommendedListings() {
    final raw = _home.get(_kRecommendedListings);
    if (raw is! List) return const [];
    return raw.map((e) => Listing.fromJson(_asStringMap(e))).toList();
  }

  static Future<void> putRecommendedListings(List<Listing> listings) async {
    final trimmed =
        listings.take(_recentListingsMax).map(_listingToCacheable).toList();
    await _home.put(_kRecommendedListings, trimmed);
    await _home.put(
      _kRecommendedListingsUpdatedAt,
      DateTime.now().toIso8601String(),
    );
  }

  static DateTime? get recommendedListingsUpdatedAt {
    final iso = _home.get(_kRecommendedListingsUpdatedAt);
    if (iso is! String) return null;
    return DateTime.tryParse(iso);
  }

  /// Wipes the full home snapshot (trending + recent + updated-at).
  static Future<void> clearHomeSnapshot() => _home.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Pending posts queue
  // ══════════════════════════════════════════════════════════════════════

  static Box get _pending => Hive.box(_pendingPostsBox);

  static List<PendingPost> getPendingPosts() {
    return _pending.values
        .map((v) => PendingPost.fromMap(_asStringMap(v)))
        .toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  }

  static Future<void> enqueuePendingPost(PendingPost post) =>
      _pending.put(post.id, post.toMap());

  static Future<void> removePendingPost(String id) => _pending.delete(id);

  static Future<void> clearPendingPosts() => _pending.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Pending view events (write-behind queue)
  // ══════════════════════════════════════════════════════════════════════
  //
  // Fire-and-forget view registrations that failed due to no network.
  // Keyed by productId so the same product viewed N times offline still
  // occupies one slot (backend-side dedupe is also fine — either works).

  static Box get _pendingViews => Hive.box(_pendingViewsBox);

  /// Product IDs with a pending view registration. Order doesn't matter;
  /// the server-side counter is monotonic.
  static List<String> getPendingViewIds() =>
      _pendingViews.keys.cast<String>().toList();

  static Future<void> enqueuePendingView(String productId) =>
      _pendingViews.put(productId, DateTime.now().toIso8601String());

  static Future<void> removePendingView(String productId) =>
      _pendingViews.delete(productId);

  static Future<void> clearPendingViews() => _pendingViews.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Pending category-view events (write-behind queue)
  // ══════════════════════════════════════════════════════════════════════
  //
  // When the user opens a product detail the app records which category
  // was viewed so the backend can build personalised recommendations.
  // If the POST fails (offline / 5xx) the category is queued here and
  // flushed by [ApiService.flushPendingCategoryViews] on reconnect.
  // Keyed by category name so opening the same category N times offline
  // still occupies a single slot (deduplicated).

  static Box get _pendingCategoryViews =>
      Hive.box(_pendingCategoryViewsBox);

  static List<String> getPendingCategoryViewIds() =>
      _pendingCategoryViews.keys.cast<String>().toList();

  static Future<void> enqueuePendingCategoryView(String category) =>
      _pendingCategoryViews.put(
          category, DateTime.now().toIso8601String());

  static Future<void> removePendingCategoryView(String category) =>
      _pendingCategoryViews.delete(category);

  static Future<void> clearPendingCategoryViews() =>
      _pendingCategoryViews.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Pending buyer→seller contact events (write-behind queue)
  // ══════════════════════════════════════════════════════════════════════
  //
  // The user tapped "Contact Seller via WhatsApp" but we couldn't reach the
  // backend (offline / 5xx). Each row carries the buyer→seller pair plus the
  // product the contact came from, so the BQ "% of orders preceded by a
  // direct contact" stays accurate after reconnect.

  static Box get _pendingContacts => Hive.box(_pendingContactsBox);

  /// Return every queued contact event as a list of plain maps. Order is
  /// preserved by the original microsecond-precision key.
  static List<Map<String, dynamic>> getPendingContacts() {
    final keys = _pendingContacts.keys.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    return keys
        .map((k) => _asStringMap(_pendingContacts.get(k))..putIfAbsent('_key', () => k.toString()))
        .toList();
  }

  /// Enqueue a contact event for later flush. Keyed by microsecond timestamp
  /// so multiple events for the same product don't collide.
  static Future<void> enqueuePendingContact({
    required String productId,
    required String sellerId,
    String channel = 'whatsapp',
  }) {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    return _pendingContacts.put(key, {
      'product_id': productId,
      'seller_id': sellerId,
      'channel': channel,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> removePendingContact(String key) =>
      _pendingContacts.delete(key);

  static Future<void> clearPendingContacts() => _pendingContacts.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Product stats cache (per-product view counts)
  // ══════════════════════════════════════════════════════════════════════
  //
  // Sellers want current numbers on their own products. We still go to the
  // network first (see [ApiService.getProductStats]) but keep a cache as a
  // fallback so an offline seller sees "24 views · 3h ago" instead of a
  // blank badge.

  static Box get _productStats => Hive.box(_productStatsBox);

  /// Cached stats for [productId], or null if we've never fetched them.
  /// The stored map mirrors the API response shape.
  static ({Map<String, dynamic> data, DateTime updatedAt})? getProductStats(
      String productId) {
    final raw = _productStats.get(productId);
    if (raw is! Map) return null;
    final map = _asStringMap(raw);
    final iso = map['_cached_at'] as String?;
    final updatedAt =
        iso != null ? DateTime.tryParse(iso) : null;
    if (updatedAt == null) return null;
    final data = Map<String, dynamic>.from(map)..remove('_cached_at');
    return (data: data, updatedAt: updatedAt);
  }

  static Future<void> putProductStats(
    String productId,
    Map<String, dynamic> stats,
  ) {
    final payload = {
      ...stats,
      '_cached_at': DateTime.now().toIso8601String(),
    };
    return _productStats.put(productId, payload);
  }

  static Future<void> clearProductStats() => _productStats.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Product orders cache (seller view of orders on their product)
  // ══════════════════════════════════════════════════════════════════════

  static Box get _productOrders => Hive.box(_productOrdersBox);

  /// Returns cached orders list for [productId], or null if never fetched.
  static ({List<Map<String, dynamic>> orders, DateTime updatedAt})?
      getProductOrders(String productId) {
    final raw = _productOrders.get(productId);
    if (raw is! Map) return null;
    final wrapper = Map<String, dynamic>.from(raw);
    final iso = wrapper['_cached_at'] as String?;
    final updatedAt = iso != null ? DateTime.tryParse(iso) : null;
    if (updatedAt == null) return null;
    final rawList = wrapper['orders'];
    if (rawList is! List) return null;
    final orders = rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return (orders: orders, updatedAt: updatedAt);
  }

  static Future<void> putProductOrders(
    String productId,
    List<Map<String, dynamic>> orders,
  ) {
    return _productOrders.put(productId, {
      'orders': orders,
      '_cached_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> clearProductOrders() => _productOrders.clear();

  // ══════════════════════════════════════════════════════════════════════
  // Session cleanup
  // ══════════════════════════════════════════════════════════════════════

  /// Wipe every Hive box that belongs to the current user's session. Call
  /// from the logout path to stop the next account from seeing leftover
  /// favorites, a stale home snapshot, cached user info, or — critically —
  /// a pending post / view event that would otherwise be re-uploaded under
  /// the wrong JWT.
  static Future<void> wipeUserScoped() async {
    await Future.wait([
      clearFavorites(),
      clearUser(),
      clearHomeSnapshot(),
      clearPendingPosts(),
      clearPendingViews(),
      clearPendingContacts(),
      clearProductStats(),
      clearProductOrders(),
      clearPendingCategoryViews(),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════════════

  /// Hive returns `Map<dynamic, dynamic>` — normalize to `Map<String, dynamic>`
  /// so the model factories can consume it without casting gymnastics.
  static Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  /// Serialize a [Listing] to a Hive-friendly map. We can't reuse
  /// [Listing.toJson] because it only serializes the fields needed for
  /// creating a listing (no seller info, no timestamps).
  static Map<String, dynamic> _listingToCacheable(Listing l) => {
        if (l.id != null) 'id': l.id,
        'title': l.title,
        'description': l.description,
        'category': l.category,
        'building_location': l.buildingLocation,
        'price': l.price,
        if (l.condition != null) 'condition': l.condition,
        'image_urls': l.imageUrls,
        'is_sold': l.isSold,
        if (l.sellerId != null) 'seller_id': l.sellerId,
        if (l.sellerName != null) 'seller_name': l.sellerName,
        if (l.sellerMajor != null) 'seller_major': l.sellerMajor,
        if (l.sellerAvatarUrl != null) 'seller_avatar_url': l.sellerAvatarUrl,
        if (l.sellerPhone != null) 'seller_phone': l.sellerPhone,
        if (l.createdAt != null) 'created_at': l.createdAt!.toIso8601String(),
      };
}
