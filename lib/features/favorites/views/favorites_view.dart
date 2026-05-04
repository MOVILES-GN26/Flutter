import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/cache/image_cache_manager.dart';
import 'package:provider/provider.dart';
import '../../../core/models/listing.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../catalog/views/product_detail_view.dart';
import '../viewmodels/favorites_viewmodel.dart';

/// Favorites screen — shows all products saved by the authenticated user.
class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesViewModel>().loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: Column(
        children: [
          const OfflineBanner(
            message:
                'Offline · showing saved favorites · changes are paused until reconnect',
          ),
          Expanded(
            child: Consumer<FavoritesViewModel>(
              builder: (context, vm, _) {
          // ── Loading ──
          if (vm.status == FavoritesStatus.loading && vm.favorites.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4C84A)),
            );
          }

          // ── Error ──
          if (vm.status == FavoritesStatus.error && vm.favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off,
                        size: 48, color: Color(0xFF96914F)),
                    const SizedBox(height: 12),
                    Text(
                      vm.errorMessage ?? 'Something went wrong.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF96914F)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vm.loadFavorites(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Empty ──
          if (vm.favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 72,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No favorites yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse the catalog and tap ♥ on a product to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── List ──
          return RefreshIndicator(
            color: const Color(0xFFD4C84A),
            onRefresh: () => vm.loadFavorites(),
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: vm.favorites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = vm.favorites[index];
                return _FavoriteCard(
                  item: item,
                  onUnfavorite: () {
                    if (item.id != null) vm.removeFavorite(item.id!);
                  },
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailView(item: item),
                    ),
                  ),
                );
              },
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual favorite card ──
class _FavoriteCard extends StatelessWidget {
  final Listing item;
  final VoidCallback onUnfavorite;
  final VoidCallback onTap;

  const _FavoriteCard({
    required this.item,
    required this.onUnfavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E5D1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Product image ──
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 110,
                height: 110,
                child: item.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        cacheManager: AndesHubImageCacheManager.instance,
                        imageUrl: item.imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFD4C84A)),
                        ),
                        errorWidget: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    // Price + condition chip
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '\$${item.price.toStringAsFixed(0)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B7E3B),
                            ),
                          ),
                        ),
                        if (item.condition != null &&
                            item.condition!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5ECCF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.condition!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF8B7E3B)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Unfavorite button ──
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon:
                    const Icon(Icons.favorite, color: Colors.red, size: 22),
                tooltip: 'Remove from favorites',
                onPressed: onUnfavorite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF5ECCF),
      child: const Center(
        child:
            Icon(Icons.image_outlined, size: 36, color: Color(0xFF8B7E3B)),
      ),
    );
  }
}
