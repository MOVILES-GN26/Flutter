import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../payments/views/complete_payment_view.dart';

///
/// Receives a [Listing] and displays its full information:
/// hero image, title, price, seller info, description, and action buttons.
class ProductDetailView extends StatefulWidget {
  final Listing item;

  const ProductDetailView({super.key, required this.item});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  int? _viewCount;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _registerAndFetchViews();
  }

  Future<void> _registerAndFetchViews() async {
    final id = widget.item.id;
    if (id == null) return;

    final currentUserId = await _getCurrentUserId();
    final isOwner = currentUserId != null && currentUserId == widget.item.sellerId;

    if (mounted) setState(() => _isOwner = isOwner);

    if (!isOwner) {
      await _apiService.registerView(id);
    } else {
      final stats = await _apiService.getProductStats(id);
      if (stats != null && mounted) {
        setState(() {
          _viewCount = stats['total_views'] as int? ??
              stats['views'] as int? ??
              stats['count'] as int?;
        });
      }
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Product Details',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 280,
                        color: const Color(0xFFF5ECCF),
                        child: widget.item.imageUrls.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.item.imageUrls.first,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFD4C84A)),
                                ),
                                errorWidget: (_, _, _) =>
                                    _buildImagePlaceholder(),
                              )
                            : _buildImagePlaceholder(),
                      ),
                      if (_isOwner && _viewCount != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.visibility_outlined,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  '$_viewCount views',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // ── Title ──
                        Text(
                          widget.item.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // ── Price ──
                        Text(
                          '\$${widget.item.price.toStringAsFixed(0)}',
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
                        if (widget.item.buildingLocation.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 18, color: Color(0xFF8B7E3B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.item.buildingLocation,
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
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
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
    final sellerName = widget.item.sellerName ?? 'Unknown Seller';
    final sellerMajor = widget.item.sellerMajor ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seller Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                sellerName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF96914F),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Theme.of(context).colorScheme.onSurface),
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
          backgroundImage: widget.item.sellerAvatarUrl != null
              ? CachedNetworkImageProvider(widget.item.sellerAvatarUrl!)
              : null,
          child: widget.item.sellerAvatarUrl == null
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
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _isOwner
          ? const Center(
              child: Text(
                'This is your listing',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Buy Now → navigate to Complete Payment
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CompletePaymentView(item: widget.item),
                  ),
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
              onPressed: () async {
                final rawPhone = widget.item.sellerPhone;
                if (rawPhone == null || rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Seller phone number not available.')),
                  );
                  return;
                }
                final phone = rawPhone.startsWith('57')
                    ? rawPhone
                    : '57$rawPhone';
                final message = Uri.encodeComponent(
                    'Hola, estoy interesado en comprar ${widget.item.title}');
                final uri = Uri.parse('https://wa.me/$phone?text=$message');
                if (!await launchUrl(uri,
                    mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not open WhatsApp.')),
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
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
