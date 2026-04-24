import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/listing.dart';

/// SQLite-backed relational store. Three tables:
///
///   * `listings`        — write-through cache of every listing the catalog
///                          has pulled from the API. Powers offline browsing
///                          and the filter/search screen when the network
///                          is unavailable.
///   * `recent_views`    — rows written whenever the user opens a product
///                          detail screen. Join with `listings` to render a
///                          "Recently Viewed" strip.
///   * `search_history`  — rolling log of catalog search queries, used by
///                          the search bar for autocompletion.
class LocalDbService {
  LocalDbService._();

  static Database? _db;
  static const String _dbName = 'andeshub.db';
  static const int _dbVersion = 1;

  static const String tListings = 'listings';
  static const String tRecentViews = 'recent_views';
  static const String tSearchHistory = 'search_history';

  /// How long a cached listing stays around before being purged.
  static const Duration _listingsTtl = Duration(days: 30);

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Opens the database (creating tables on first run) and purges stale
  /// cached listings. Safe to call from [main] — callers that only hit the
  /// other `static` methods would open it lazily anyway, but explicit init
  /// avoids a first-query latency hit.
  static Future<void> init() async {
    await _database;
    // Fire-and-forget: don't block startup on cleanup.
    purgeStaleListings();
  }

  static Future<Database> get _database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tListings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        building_location TEXT NOT NULL,
        price REAL NOT NULL,
        condition TEXT,
        image_urls TEXT NOT NULL,
        seller_id TEXT,
        seller_name TEXT,
        seller_major TEXT,
        seller_avatar_url TEXT,
        seller_phone TEXT,
        created_at TEXT,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_listings_category ON $tListings(category)');
    await db.execute(
        'CREATE INDEX idx_listings_building ON $tListings(building_location)');
    await db.execute(
        'CREATE INDEX idx_listings_price ON $tListings(price)');

    await db.execute('''
      CREATE TABLE $tRecentViews (
        product_id TEXT PRIMARY KEY,
        viewed_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES $tListings(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_views_viewed_at ON $tRecentViews(viewed_at DESC)');

    await db.execute('''
      CREATE TABLE $tSearchHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        searched_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_search_searched_at ON $tSearchHistory(searched_at DESC)');
  }

  // ══════════════════════════════════════════════════════════════════════
  // Listings cache
  // ══════════════════════════════════════════════════════════════════════

  /// UPSERT a batch of listings in a single transaction.
  /// Entries without an [Listing.id] are skipped (cannot be keyed).
  static Future<void> upsertListings(List<Listing> listings) async {
    if (listings.isEmpty) return;
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final l in listings) {
      if (l.id == null) continue;
      batch.insert(
        tListings,
        _listingToRow(l, cachedAt: now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Query the listings cache with the same filters the API accepts.
  /// Returns an empty list if the cache has no matches.
  static Future<List<Listing>> queryListings({
    String? search,
    String? category,
    String? condition,
    String? priceSort,
    List<String>? buildings,
    int? limit,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];

    if (search != null && search.isNotEmpty) {
      where.add('(title LIKE ? OR description LIKE ?)');
      final like = '%$search%';
      args..add(like)..add(like);
    }
    if (category != null && category.isNotEmpty) {
      where.add('category = ?');
      args.add(category);
    }
    if (condition != null && condition.isNotEmpty) {
      where.add('condition = ?');
      args.add(condition);
    }
    if (buildings != null && buildings.isNotEmpty) {
      final placeholders = List.filled(buildings.length, '?').join(',');
      where.add('building_location IN ($placeholders)');
      args.addAll(buildings);
    }

    String? orderBy;
    switch (priceSort) {
      case 'Lowest Price':
        orderBy = 'price ASC';
        break;
      case 'Highest Price':
        orderBy = 'price DESC';
        break;
      default:
        orderBy = 'cached_at DESC';
    }

    final rows = await db.query(
      tListings,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
      limit: limit,
    );
    return rows.map(_rowToListing).toList();
  }

  static Future<void> clearListings() async {
    final db = await _database;
    await db.delete(tListings);
  }

  /// Deletes listings whose `cached_at` is older than [maxAge] (default
  /// [_listingsTtl]). Returns the number of rows removed. The recent_views
  /// rows that referenced them cascade automatically via the FK.
  static Future<int> purgeStaleListings({Duration? maxAge}) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(maxAge ?? _listingsTtl);
    return db.delete(
      tListings,
      where: 'cached_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Recent views
  // ══════════════════════════════════════════════════════════════════════

  /// Record that the user opened [listing]'s detail screen. Upserts the
  /// listing row so the join against `listings` always returns data.
  static Future<void> registerView(Listing listing) async {
    if (listing.id == null) return;
    final db = await _database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      txn.insert(
        tListings,
        _listingToRow(listing, cachedAt: now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      txn.insert(
        tRecentViews,
        {'product_id': listing.id, 'viewed_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Returns the last [limit] distinct products the user viewed, newest first.
  static Future<List<Listing>> getRecentlyViewed({int limit = 10}) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT l.* FROM $tListings l
      INNER JOIN $tRecentViews v ON l.id = v.product_id
      ORDER BY v.viewed_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(_rowToListing).toList();
  }

  static Future<void> clearRecentViews() async {
    final db = await _database;
    await db.delete(tRecentViews);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Search history
  // ══════════════════════════════════════════════════════════════════════

  /// Record a search query. No-ops for empty strings. Upserts by query so
  /// the list of recents doesn't duplicate the same term.
  static Future<void> recordSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        tSearchHistory,
        where: 'query = ?',
        whereArgs: [trimmed],
      );
      await txn.insert(tSearchHistory, {
        'query': trimmed,
        'searched_at': now,
      });
    });
  }

  static Future<List<String>> getRecentSearches({int limit = 5}) async {
    final db = await _database;
    final rows = await db.query(
      tSearchHistory,
      columns: ['query'],
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return rows.map((r) => r['query'] as String).toList();
  }

  static Future<void> clearSearchHistory() async {
    final db = await _database;
    await db.delete(tSearchHistory);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Session cleanup
  // ══════════════════════════════════════════════════════════════════════

  /// Wipes the tables that hold behavior tied to the logged-in user —
  /// recently-viewed products and search queries. The `listings` cache
  /// is intentionally left behind because it is public catalog data and
  /// gives the next account an instant first paint.
  static Future<void> clearUserScopedData() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(tRecentViews);
      await txn.delete(tSearchHistory);
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // Row <-> model mapping
  // ══════════════════════════════════════════════════════════════════════

  static Map<String, Object?> _listingToRow(
    Listing l, {
    required String cachedAt,
  }) {
    return {
      'id': l.id,
      'title': l.title,
      'description': l.description,
      'category': l.category,
      'building_location': l.buildingLocation,
      'price': l.price,
      'condition': l.condition,
      'image_urls': jsonEncode(l.imageUrls),
      'seller_id': l.sellerId,
      'seller_name': l.sellerName,
      'seller_major': l.sellerMajor,
      'seller_avatar_url': l.sellerAvatarUrl,
      'seller_phone': l.sellerPhone,
      'created_at': l.createdAt?.toIso8601String(),
      'cached_at': cachedAt,
    };
  }

  static Listing _rowToListing(Map<String, Object?> r) {
    final imageUrlsRaw = r['image_urls'] as String? ?? '[]';
    final List<dynamic> decoded = jsonDecode(imageUrlsRaw) as List<dynamic>;
    return Listing(
      id: r['id'] as String?,
      title: r['title'] as String? ?? '',
      description: r['description'] as String? ?? '',
      category: r['category'] as String? ?? '',
      buildingLocation: r['building_location'] as String? ?? '',
      price: (r['price'] as num?)?.toDouble() ?? 0,
      condition: r['condition'] as String?,
      imageUrls: decoded.cast<String>(),
      sellerId: r['seller_id'] as String?,
      sellerName: r['seller_name'] as String?,
      sellerMajor: r['seller_major'] as String?,
      sellerAvatarUrl: r['seller_avatar_url'] as String?,
      sellerPhone: r['seller_phone'] as String?,
      createdAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'] as String)
          : null,
    );
  }
}
