import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom [CacheManager] tuned for AndesHub product/avatar images.
///
/// ## Image cache flow
///
/// ```
/// URL request
///   → 1. Flutter's in-memory ImageCache (LRU, 200 images / 150 MB)
///   → 2. flutter_cache_manager disk cache (LRU, 400 objects / 30 days)
///   → 3. Network fetch (HTTP GET with optional auth headers)
///   → 4. Decode + paint
/// ```
///
/// ## Configuration rationale
///
/// | Parameter             | Default         | AndesHub value | Why                                                                    |
/// |-----------------------|-----------------|----------------|------------------------------------------------------------------------|
/// | `stalePeriod`         | 7 days          | **30 days**    | Product images rarely change; 30 d avoids refetches for static assets  |
/// | `maxNrOfCacheObjects` | 200             | **400**        | Catalog has 200+ SKUs; 200 cap causes thrashing on infinite-scroll     |
/// | `key` (cache name)    | `libCachedImage` | `andesHubImages` | Isolated from any other CacheManager instance in the process         |
///
/// ## Memory-tier configuration (set in `main.dart`)
///
/// ```dart
/// PaintingBinding.instance.imageCache.maximumSize = 200;       // images
/// PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB
/// ```
///
/// Default Flutter values are 100 images / 100 MB; the Home screen's
/// horizontal scroll loads many thumbnails at once and the default causes
/// visible reloads when scrolling back.
class AndesHubImageCacheManager {
  AndesHubImageCacheManager._();

  /// Singleton key so all call-sites share the same disk bucket.
  static const String _cacheKey = 'andesHubImages';

  /// The shared [CacheManager] instance used across the entire app.
  ///
  /// Pass this to every `CachedNetworkImage(cacheManager: ...)` widget so
  /// images land in the AndesHub-specific bucket with the custom policy.
  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,

      /// How long a cached file is considered "fresh". After this period
      /// the next request will trigger a conditional GET (ETag / If-Modified-Since).
      /// 30 days is safe for product images that are immutable once uploaded.
      stalePeriod: const Duration(days: 30),

      /// Maximum number of files kept on disk. 400 covers the typical catalog
      /// size (200–300 listings × 1–2 images each) without unbounded growth.
      maxNrOfCacheObjects: 400,
    ),
  );
}
