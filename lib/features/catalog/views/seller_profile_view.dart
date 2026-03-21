import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import 'product_detail_view.dart';

const _kOlive = Color(0xFF8B7E3B);
const _kYellow = Color(0xFFD4C84A);

/// Public profile of a seller, accessible from a product's detail page.
class SellerProfileView extends StatefulWidget {
  final String sellerId;
  final String? sellerName;
  final String? sellerMajor;
  final String? sellerAvatarUrl;
  final String? sellerPhone;

  const SellerProfileView({
    super.key,
    required this.sellerId,
    this.sellerName,
    this.sellerMajor,
    this.sellerAvatarUrl,
    this.sellerPhone,
  });

  @override
  State<SellerProfileView> createState() => _SellerProfileViewState();
}

class _SellerProfileViewState extends State<SellerProfileView> {
  final ApiService _apiService = ApiService();
  List<Listing> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchListings();
  }

  Future<void> _fetchListings() async {
    final results = await _apiService.getUserProducts(widget.sellerId);
    if (mounted) setState(() { _listings = results; _loading = false; });
  }

  Future<void> _openWhatsApp() async {
    final rawPhone = widget.sellerPhone;
    if (rawPhone == null || rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller phone number not available.')),
      );
      return;
    }
    final phone = rawPhone.startsWith('57') ? rawPhone : '57$rawPhone';
    final message = Uri.encodeComponent(
        'Hola, vi tu perfil en AndesHub y me gustaría preguntarte algo.');
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.sellerName ?? 'Seller';
    final hasPhone = widget.sellerPhone?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Seller Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (hasPhone)
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: 'WhatsApp',
              onPressed: _openWhatsApp,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _kYellow,
        onRefresh: () async => _fetchListings(),
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(child: _buildHeader(cs, name)),

            // ── Listings title ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  '${name.split(' ').first}\'s Listings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),

            // ── Grid or empty / loading ──
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _kYellow),
                ),
              )
            else if (_listings.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No listings yet.',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        fontSize: 14),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _listings[index];
                      return _ListingCard(
                        item: item,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailView(item: item),
                          ),
                        ),
                      );
                    },
                    childCount: _listings.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5ECCF),
              border: Border.all(color: _kYellow.withValues(alpha: 0.5), width: 2),
            ),
            child: ClipOval(
              child: widget.sellerAvatarUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: widget.sellerAvatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person, size: 52, color: _kOlive),
                    )
                  : const Icon(Icons.person, size: 52, color: _kOlive),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),

          // Major
          if (widget.sellerMajor?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              widget.sellerMajor!,
              style: const TextStyle(
                fontSize: 13,
                color: _kOlive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // WhatsApp button
          if (widget.sellerPhone?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openWhatsApp,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Contact via WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  final Listing item;
  final VoidCallback onTap;
  const _ListingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF5ECCF),
                child: item.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kYellow),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.image_outlined,
                              size: 36, color: _kOlive),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image_outlined,
                            size: 36, color: _kOlive),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
