import 'package:flutter/material.dart';
import '../../post/models/post_item.dart';

/// Product Detail page matching the Figma design.
///
/// Receives a [PostItem] and displays its full information:
/// hero image, title, price, seller info, description, and action buttons.
class ProductDetailView extends StatelessWidget {
  final PostItem item;

  const ProductDetailView({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Product Details',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Product Image ──
                  Container(
                    width: double.infinity,
                    height: 280,
                    color: const Color(0xFFF5ECCF),
                    child: item.imageUrls.isNotEmpty
                        ? Image.network(
                            item.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // ── Title ──
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // ── Price ──
                        Text(
                          '\$${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B7E3B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Seller Information ──
                        _buildSellerSection(context),
                        const SizedBox(height: 24),

                        // ── Location ──
                        if (item.buildingLocation.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 18, color: Color(0xFF8B7E3B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.buildingLocation,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF96914F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Description ──
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom action buttons ──
          _buildBottomActions(context),
        ],
      ),
    );
  }

  // ── Seller section ──
  Widget _buildSellerSection(BuildContext context) {
    final sellerName = item.sellerName ?? 'Unknown Seller';
    final sellerMajor = item.sellerMajor ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sellerName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF96914F),
                ),
              ),
              const Text(
                'Seller Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (sellerMajor.isNotEmpty)
                Text(
                  'Major: $sellerMajor',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF96914F),
                  ),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to seller profile using item.sellerId
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.black87),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Seller avatar
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFFF5ECCF),
          backgroundImage: item.sellerAvatarUrl != null
              ? NetworkImage(item.sellerAvatarUrl!)
              : null,
          child: item.sellerAvatarUrl == null
              ? const Icon(Icons.person, size: 30, color: Color(0xFF8B7E3B))
              : null,
        ),
      ],
    );
  }

  // ── Bottom actions: Buy Now + WhatsApp ──
  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Buy Now
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement purchase / checkout flow
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase flow coming soon!')),
                );
              },
              child: const Text('Buy Now'),
            ),
          ),
          const SizedBox(height: 10),
          // Contact Seller via WhatsApp
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                // TODO: Open WhatsApp with seller's phone number
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('WhatsApp contact coming soon!')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Color(0xFFE8E5D1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Contact Seller via WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: Color(0xFF8B7E3B),
      ),
    );
  }
}
