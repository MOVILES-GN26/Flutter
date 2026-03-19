import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../catalog/views/product_detail_view.dart';
import '../../../core/constants/post_categories.dart';
import '../../../core/models/listing.dart';
import '../viewmodels/home_viewmodel.dart';

/// Vista de Home
class HomeView extends StatefulWidget {
  const HomeView({super.key});
  
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadHomeData();
    });
  }
  
  @override
  void dispose() {
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
            if (viewModel.status == HomeStatus.loading &&
                viewModel.recentlyAddedItems.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (viewModel.status == HomeStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(viewModel.errorMessage ?? 'Error al cargar datos'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => viewModel.loadHomeData(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Hero section con imagen de fondo y texto
                  _buildHeroSection(),
                  
                  // Search bar
                  _buildSearchBar(),
                  
                  // Categorías
                  _buildCategories(viewModel),
                  
                  // Recently Added
                  _buildRecentlyAdded(viewModel),
                ],
              ),
            );
          },
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
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.5),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                color: Colors.grey,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No trending categories yet — start browsing!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: trending.map((category) {
                final emoji = categoryEmojis[category] ?? '📦';
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
                      Text(emoji,
                          style: const TextStyle(fontSize: 18)),
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
                color: Colors.grey.shade200,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFD4C84A)),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey.shade300,
                          child: Icon(Icons.image,
                              size: 60, color: Colors.grey.shade400),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: Icon(
                          Icons.image,
                          size: 60,
                          color: Colors.grey.shade400,
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
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
