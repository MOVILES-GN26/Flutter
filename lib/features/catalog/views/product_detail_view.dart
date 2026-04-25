import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/order.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../payments/views/complete_payment_view.dart';
import 'seller_profile_view.dart';
import '../../profile/views/profile_view.dart';

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
  int? _favoritesCount;
  bool _isOwner = false;
  String? _currentUserId;

  // Order state
  Order? _order;
  bool _orderLoaded = false;
  bool _confirmingPayment = false;
  bool _productHasActiveOrder = false;

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

    if (mounted) {
      setState(() {
        _isOwner = isOwner;
        _currentUserId = currentUserId;
      });
    }

    // Load order for this product (buyer: from local storage; seller: from API)
    await _loadOrder(id, isOwner: isOwner);

    if (!isOwner) {
      await _apiService.registerView(id);
    } else {
      final stats = await _apiService.getProductStats(id);
      final favCount = await _apiService.getFavoritesCount(id);
      if (mounted) {
        setState(() {
          if (stats != null) {
            _viewCount = stats['total_views'] as int? ??
                stats['views'] as int? ??
                stats['count'] as int?;
          }
          _favoritesCount = favCount;
        });
      }
    }
  }

  /// Load the order associated with this product for the current user.
  /// - Buyer: check local storage for a cached orderId, then fetch it.
  /// - Seller: query orders for this product and find any active one.
  Future<void> _loadOrder(String productId, {required bool isOwner}) async {
    try {
      Order? order;

      if (isOwner) {
        // Seller: query GET /orders?product_id=xxx and pick the first active order
        final productOrders =
            await _apiService.getOrdersForProduct(productId);
        const activeStatuses = {
          'payment_uploaded',
          'confirmed',
          'shipping',
          'completed',
        };
        for (final o in productOrders) {
          if (activeStatuses.contains(o.status)) {
            order = o;
            break;
          }
        }
      } else {
        // Buyer: check local storage for a pending order
        final storedOrderId =
            await _storageService.getOrderIdForProduct(productId);
        if (storedOrderId != null) {
          order = await _apiService.getOrderById(storedOrderId);
          // If the order was confirmed/completed, clean up local storage
          if (order != null &&
              (order.isConfirmed ||
                  order.status == 'completed' ||
                  order.status == 'cancelled')) {
            await _storageService.removePendingPaymentOrder(productId);
          }
        }

        // Check if any non-cancelled order exists for this product
        final productOrders = await _apiService.getOrdersForProduct(productId);
        final hasActive = productOrders.any((o) => o.status != 'cancelled');
        if (mounted) setState(() => _productHasActiveOrder = hasActive);
      }

      if (mounted) setState(() { _order = order; _orderLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _orderLoaded = true);
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
                                  '$_viewCount views',
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

                        // ── Order status banner ──
                        if (_order != null) ...[
                          _buildOrderStatusBanner(),
                          const SizedBox(height: 16),
                        ],
                        // ── Payment proof image (visible to seller) ──
                        if (_isOwner &&
                            _order != null &&
                            (_order!.paymentProofUrl?.isNotEmpty ?? false)) ...[  
                          _buildPaymentProofSection(),
                          const SizedBox(height: 16),
                        ],
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
              ? CachedNetworkImageProvider(widget.item.sellerAvatarUrl!)
              : null,
          child: widget.item.sellerAvatarUrl == null
              ? const Icon(Icons.person, size: 30, color: Color(0xFF8B7E3B))
              : null,
        ),
      ],
    );
  }

  // ── Payment proof image (shown to seller when buyer has uploaded proof) ──
  Widget _buildPaymentProofSection() {
    final proofUrl = _order!.paymentProofUrl!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Proof',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: proofUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            placeholder: (_, _) => Container(
              height: 180,
              color: const Color(0xFFF5ECCF),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4C84A)),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF5ECCF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 48, color: Color(0xFF8B7E3B)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Order status banner (shown below image for buyer and seller) ──
  Widget _buildOrderStatusBanner() {    final order = _order!;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (order.status) {
      case 'payment_uploaded':
        bgColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        icon = Icons.upload_file_outlined;
        break;
      case 'confirmed':
        bgColor = const Color(0xFFD1E7DD);
        textColor = const Color(0xFF0F5132);
        icon = Icons.check_circle_outline;
        break;
      case 'shipping':
        bgColor = const Color(0xFFCFE2FF);
        textColor = const Color(0xFF084298);
        icon = Icons.local_shipping_outlined;
        break;
      case 'completed':
        bgColor = const Color(0xFFD1E7DD);
        textColor = const Color(0xFF0F5132);
        icon = Icons.done_all;
        break;
      case 'cancelled':
        bgColor = const Color(0xFFF8D7DA);
        textColor = const Color(0xFF842029);
        icon = Icons.cancel_outlined;
        break;
      default:
        bgColor = const Color(0xFFE2E3E5);
        textColor = const Color(0xFF41464B);
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isOwner
                  ? 'Order status: ${order.statusLabel}'
                  : 'Your order status: ${order.statusLabel}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
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
          ? _buildSellerBottomContent(context)
          : _buildBuyerBottomContent(context),
    );
  }

  // Seller-side bottom content
  Widget _buildSellerBottomContent(BuildContext context) {
    // If there's a payment_uploaded order, show confirm + buyer contact
    if (_order != null && _order!.isPaymentUploaded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Confirm Payment button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _confirmingPayment
                  ? null
                  : () async {
                      setState(() => _confirmingPayment = true);
                      final success =
                          await _apiService.confirmPayment(_order!.id);
                      if (!mounted) return;
                      setState(() => _confirmingPayment = false);
                      if (success) {
                        // Remove from local storage (buyer side)
                        await _storageService.removePendingPaymentOrder(
                            widget.item.id ?? '');
                        await _loadOrder(widget.item.id ?? '',
                            isOwner: true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment confirmed successfully!'),
                              backgroundColor: Color(0xFF198754),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to confirm payment.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              icon: _confirmingPayment
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                  _confirmingPayment ? 'Confirming…' : 'Confirm Payment'),
            ),
          ),
          const SizedBox(height: 10),
          // Contact Buyer via WhatsApp (in case seller needs to discuss/reject)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _launchWhatsApp(
                phone: _order!.buyerPhone,
                name: _order!.buyerName,
                isBuyer: true,
              ),
              icon: const Icon(Icons.chat_outlined),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: const BorderSide(color: Color(0xFFE8E5D1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              label: Text(
                'Contact ${_order!.buyerName} via WhatsApp',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    // No pending order — just show the "your listing" label
    return const Center(
      child: Text(
        'This is your listing',
        style: TextStyle(
          fontSize: 14,
          color: Colors.black45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Buyer-side bottom content
  Widget _buildBuyerBottomContent(BuildContext context) {
    // If buyer already has an active order, show informational banner
    if (_order != null &&
        (_order!.isPaymentUploaded || _order!.isConfirmed)) {
      final message = _order!.isConfirmed
          ? 'Your payment has been confirmed by the seller.'
          : 'Payment proof submitted — awaiting seller confirmation.';
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Normal buy flow
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Buy Now → navigate to Complete Payment (disabled if product has active order)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _productHasActiveOrder
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CompletePaymentView(item: widget.item),
                      ),
                    ).then((_) {
                      // Reload order state when returning from payment screen
                      if (mounted && widget.item.id != null) {
                        _loadOrder(widget.item.id!, isOwner: false);
                      }
                    });
                  },
            child: Text(_productHasActiveOrder ? 'Not available' : 'Buy Now'),
          ),
        ),
        const SizedBox(height: 10),
        // Contact Seller via WhatsApp
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => _launchWhatsApp(
              phone: widget.item.sellerPhone,
              name: widget.item.title,
              isBuyer: false,
            ),
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
    );
  }

  Future<void> _launchWhatsApp({
    String? phone,
    required String name,
    required bool isBuyer,
  }) async {
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBuyer
                ? 'Buyer phone number not available.'
                : 'Seller phone number not available.'),
          ),
        );
      }
      return;
    }
    final normalizedPhone = phone.startsWith('57') ? phone : '57$phone';
    final message = isBuyer
        ? Uri.encodeComponent(
            'Hola, soy el vendedor de "$name" en AndesHub. ¿Podemos coordinar el pago?')
        : Uri.encodeComponent(
            'Hola, estoy interesado en comprar $name');
    final uri =
        Uri.parse('https://wa.me/$normalizedPhone?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
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
