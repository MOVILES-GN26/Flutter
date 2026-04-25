import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cache/image_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../payments/views/complete_payment_view.dart';
import 'seller_profile_view.dart';
import '../../profile/views/profile_view.dart';


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
  DateTime? _viewStatsCachedAt;
  int? _favoritesCount;
  bool _isOwner = false;
  List<Map<String, dynamic>>? _orders;

  @override
  void initState() {
    super.initState();
    _registerAndFetchViews();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favVm = context.read<FavoritesViewModel>();
      if (favVm.status == FavoritesStatus.initial) {
        favVm.loadFavorites();
      }
    });
  }

  Future<void> _registerAndFetchViews() async {
    final id = widget.item.id;
    if (id == null) return;

    final currentUserId = await _getCurrentUserId();
    final isOwner = currentUserId != null && currentUserId == widget.item.sellerId;

    if (mounted) setState(() => _isOwner = isOwner);

    if (!isOwner) {
      // Mirror the view to the local DB so the "Recently Viewed" feed keeps
      // working offline, independently of whether the remote call succeeds.
      await LocalDbService.registerView(widget.item);
      await _apiService.registerView(id);
    } else {
      final stats = await _apiService.getProductStats(id);
      final favCount = await _apiService.getFavoritesCount(id);
      final orders = await _apiService.getOrdersByProduct(id);
      if (mounted) {
        setState(() {
          if (stats != null) {
            final data = stats.data;
            _viewCount = data['total_views'] as int? ??
                data['views'] as int? ??
                data['count'] as int?;
            _viewStatsCachedAt = stats.updatedAt;
          }
          _favoritesCount = favCount;
          _orders = orders;
        });
      }
    }
  }


  String _viewsFreshnessSuffix() {
    final cached = _viewStatsCachedAt;
    if (cached == null) return '';
    final diff = DateTime.now().difference(cached);
    if (diff.inMinutes < 60) return ' · ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return ' · ${diff.inHours}h ago';
    return ' · ${diff.inDays}d ago';
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
    final favVm = context.watch<FavoritesViewModel>();
    final isFavorited =
        !_isOwner && widget.item.id != null
            ? favVm.isFavorited(widget.item.id!)
            : false;

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
        actions: [
          if (!_isOwner && widget.item.id != null)
            IconButton(
              icon: Icon(
                isFavorited ? Icons.favorite : Icons.favorite_border,
                color: isFavorited ? Colors.red : null,
              ),
              tooltip: isFavorited
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: () async {
                if (isFavorited) {
                  await favVm.removeFavorite(widget.item.id!);
                } else {
                  await favVm.addFavorite(widget.item);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(
            message:
                'Offline · cached product · checkout and live stats are unavailable',
            lastUpdated: _viewStatsCachedAt,
          ),
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
                                cacheManager: AndesHubImageCacheManager.instance,
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
                      if (_isOwner &&
                          (_viewCount != null || _favoritesCount != null))
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_viewCount != null) ...[
                                _statBadge(
                                  Icons.visibility_outlined,
                                  '$_viewCount views${_viewsFreshnessSuffix()}',
                                ),
                                if (_favoritesCount != null)
                                  const SizedBox(width: 6),
                              ],
                              if (_favoritesCount != null)
                                _statBadge(
                                  Icons.favorite,
                                  '$_favoritesCount favorites',
                                  iconColor: Colors.red,
                                ),
                            ],
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

                        // ── Orders section (visible to owner only) ──
                        if (_isOwner && _orders != null && _orders!.isNotEmpty)
                          _buildOrdersSection(context),
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
                  if (_isOwner) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileView()),
                    );
                    return;
                  }
                  if (widget.item.sellerId == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SellerProfileView(
                        sellerId: widget.item.sellerId!,
                        sellerName: widget.item.sellerName,
                        sellerMajor: widget.item.sellerMajor,
                        sellerAvatarUrl: widget.item.sellerAvatarUrl,
                        sellerPhone: widget.item.sellerPhone,
                      ),
                    ),
                  );
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
              ? CachedNetworkImageProvider(widget.item.sellerAvatarUrl!,
                  cacheManager: AndesHubImageCacheManager.instance)
              : null,
          child: widget.item.sellerAvatarUrl == null
              ? const Icon(Icons.person, size: 30, color: Color(0xFF8B7E3B))
              : null,
        ),
      ],
    );
  }

  // ── Orders section ──
  Widget _buildOrdersSection(BuildContext context) {
    final orders = _orders!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orders (${orders.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...orders.map((order) => _buildOrderCard(context, order)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final proofUrl = order['payment_proof_url'] as String?;
    final delivery = order['delivery_option'] as String? ?? '—';
    final total = order['total'];
    final totalStr = total != null
        ? '\$${(total is num ? total.toStringAsFixed(0) : total.toString())}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8E5D1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (proofUrl != null && proofUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                cacheManager: AndesHubImageCacheManager.instance,
                imageUrl: proofUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  height: 200,
                  color: const Color(0xFFF5ECCF),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFD4C84A)),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  height: 200,
                  color: const Color(0xFFF5ECCF),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 48, color: Color(0xFF8B7E3B)),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFF5ECCF),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(
                child: Icon(Icons.receipt_long_outlined,
                    size: 48, color: Color(0xFF8B7E3B)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined,
                              size: 15, color: Color(0xFF8B7E3B)),
                          const SizedBox(width: 4),
                          Text(
                            delivery,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF96914F)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  totalStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B7E3B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

                // BQ Type 3 (dashboard): log the buyer→seller contact event
                // so we can later compute "% of purchases preceded by a
                // direct contact". Fire-and-forget — never block the user
                // from opening WhatsApp on this.
                final productId = widget.item.id;
                final sellerId = widget.item.sellerId;
                if (productId != null && sellerId != null && !_isOwner) {
                  // ignore: unawaited_futures
                  _apiService.recordContact(
                    productId: productId,
                    sellerId: sellerId,
                  );
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

  Widget _statBadge(IconData icon, String text,
      {Color iconColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
