import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../catalog/views/product_detail_view.dart';
import '../../../core/constants/post_categories.dart';
import '../../../core/models/listing.dart';
import '../../../core/viewmodels/connectivity_viewmodel.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/offline_banner.dart';
import '../viewmodels/home_viewmodel.dart';

/// Vista de Home — implementa Cache-then-Network (stale-while-revalidate).
/// Paints from the Hive snapshot instantly, then auto-refreshes whenever
/// connectivity comes back. Never shows a blank page — falls back to an
/// explicit "cold-start offline" empty state when no cache exists.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _searchController = TextEditingController();
  ConnectivityViewModel? _connectivity;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().loadHomeData();
      _connectivity = context.read<ConnectivityViewModel>();
      _wasOffline = _connectivity!.isOffline;
      _connectivity!.addListener(_onConnectivityChanged);
    });
  }

  /// Auto-refresh the feed the moment the device regains connectivity.
  /// Avoids the user needing to pull-to-refresh after a tunnel / elevator.
  void _onConnectivityChanged() {
    final c = _connectivity;
    if (c == null || !mounted) return;
    if (_wasOffline && c.isOnline) {
      context.read<HomeViewModel>().loadHomeData();
    }
    _wasOffline = c.isOffline;
  }

  @override
  void dispose() {
    _connectivity?.removeListener(_onConnectivityChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('AndesHub'),
      ),

      body: SafeArea(
        child: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                OfflineBanner(
                  message: viewModel.recentlyAddedItems.isEmpty
                      ? 'Offline'
                      : 'Offline · showing saved data',
                  lastUpdated: viewModel.lastUpdatedAt,
                ),
                Expanded(child: _buildBody(viewModel)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Decision tree for what to paint in the body:
  ///   * Have cached data  → render the feed (even if refresh failed).
  ///   * No cache + loading → spinner (bounded; not "infinite" since
  ///     [loadHomeData] has a timeout baked in via the API layer).
  ///   * No cache + offline → explicit cold-start empty state.
  ///   * No cache + online error → retry-enabled empty state.
  Widget _buildBody(HomeViewModel vm) {
    final hasCache = vm.recentlyAddedItems.isNotEmpty ||
        vm.trendingCategories.isNotEmpty;
    if (hasCache) return _buildFeed(vm);

    if (vm.status == HomeStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isOffline = context.read<ConnectivityViewModel>().isOffline;
    if (isOffline) {
      return EmptyStateView(
        icon: Icons.cloud_off_outlined,
        title: 'You are offline',
        message:
            "Connect once to download the AndesHub feed. You'll be able to browse it offline afterwards.",
      );
    }

    return EmptyStateView(
      icon: Icons.error_outline,
      title: "Couldn't load the feed",
      message: vm.errorMessage ?? 'Check your connection and try again.',
      actionLabel: 'Retry',
      onAction: vm.loadHomeData,
    );
  }

  Widget _buildFeed(HomeViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: viewModel.loadHomeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            _buildSearchBar(),
            _buildCategories(viewModel),
            _buildRecentlyAdded(viewModel),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildHeroSection() {
    return Container(
      height: 350,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/register-image.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.5),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Text(
              'AndesHub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your marketplace for Los Andes students. Buy, sell, and connect with your peers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Image.asset(
                'assets/icons/magnifying_glass.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search for items',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implementar búsqueda
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDD835), // Yellow
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategories(HomeViewModel viewModel) {
    final trending = viewModel.trendingCategories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending Categories',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (trending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No trending categories yet — start browsing!',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: trending.map((category) {
                final icon = categoryIcons[category] ?? Icons.category;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5ECCF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD4C84A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: const Color(0xFF8B7E3B)),
                      const SizedBox(width: 6),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B7E3B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRecentlyAdded(HomeViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recently Added',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: viewModel.recentlyAddedItems.isEmpty
                ? const Center(child: Text('No hay items disponibles'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: viewModel.recentlyAddedItems.length,
                    itemBuilder: (context, index) {
                      final item = viewModel.recentlyAddedItems[index];
                      return _buildRecentlyAddedItem(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentlyAddedItem(Listing item) {
    final imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailView(item: item),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        cacheManager: AndesHubImageCacheManager.instance,
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFD4C84A)),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.image,
                              size: 60, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image,
                          size: 60,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '\$${item.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
