import 'package:flutter_cache_manager/flutter_cache_manager.dart';


class AndesHubImageCacheManager {
  AndesHubImageCacheManager._();

  static const String _cacheKey = 'andesHubImages';
  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,

      stalePeriod: const Duration(days: 30),

      maxNrOfCacheObjects: 400,
    ),
  );
}
