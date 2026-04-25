import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/file_storage_service.dart';
import 'order_success_view.dart';

/// Screen where the buyer uploads a payment receipt/screenshot and submits proof.
class CompletePaymentView extends StatefulWidget {
  final Listing item;

  const CompletePaymentView({super.key, required this.item});

  @override
  State<CompletePaymentView> createState() => _CompletePaymentViewState();
}

class _CompletePaymentViewState extends State<CompletePaymentView> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  XFile? _proofFile;
  String _deliveryOption = 'pickup';
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) setState(() => _proofFile = file);
  }

  Future<void> _submitProof() async {
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a receipt/screenshot first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final productId = widget.item.id;
    if (productId == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create the order
      final orderData = await _apiService.createOrder(
        productId: productId,
        quantity: 1,
        deliveryOption: _deliveryOption,
      );

      if (orderData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create order. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final orderId = orderData['id'] as String?;
      if (orderId == null) return;

      // 2. Upload proof
      final bytes = await _proofFile!.readAsBytes();
      await _apiService.uploadPaymentProof(orderId, bytes, _proofFile!.name);

      // 2b. Archive a local copy so the buyer has an offline record.
      await FileStorageService.savePaymentProof(
        orderId: orderId,
        bytes: bytes,
        originalFileName: _proofFile!.name,
      );

      // 3. Navigate to success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessView(
              orderId: orderId,
              orderDate: DateTime.now(),
              total: widget.item.price,
              productTitle: widget.item.title,
              sellerPhone: widget.item.sellerPhone,
              deliveryOption: _deliveryOption,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seller = widget.item;
    final nequi = seller.sellerPhone ?? '—';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Complete Purchase',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Product card ──
                  _buildProductCard(cs),
                  const SizedBox(height: 20),

                  // ── Delivery option selector ──
                  _buildDeliverySelector(cs),
                  const SizedBox(height: 20),

                  // ── Proof of Payment ──
                  Text(
                    'Proof of Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildUploadBox(cs),
                  const SizedBox(height: 20),

                  // ── Payment instructions ──
                  Text(
                    'Transfer the money to the seller\'s account.',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'NEQUI: $nequi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Submit button ──
          _buildSubmitButton(cs),
        ],
      ),
    );
  }

  Widget _buildProductCard(ColorScheme cs) {
    final item = widget.item;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${item.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8B7E3B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: item.imageUrls.isNotEmpty
              ? CachedNetworkImage(
                  cacheManager: AndesHubImageCacheManager.instance,
                  imageUrl: item.imageUrls.first,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _imagePlaceholder(),
                  errorWidget: (_, _, _) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF5ECCF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_outlined,
          color: Color(0xFF8B7E3B), size: 32),
    );
  }

  Widget _buildDeliverySelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Option',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _deliveryChip('pickup', 'Pickup at University', cs),
            const SizedBox(width: 10),
            _deliveryChip('shipping', 'Shipping', cs),
          ],
        ),
      ],
    );
  }

  Widget _deliveryChip(String value, String label, ColorScheme cs) {
    final selected = _deliveryOption == value;
    return GestureDetector(
      onTap: () => setState(() => _deliveryOption = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4C84A) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFD4C84A) : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black87 : const Color(0xFF8B7E3B),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadBox(ColorScheme cs) {
    final hasFile = _proofFile != null;
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant,
            style: BorderStyle.solid,
            width: 1.5,
          ),
          color: cs.surfaceContainerHighest,
        ),
        child: Column(
          children: [
            Icon(
              hasFile ? Icons.check_circle_outline : Icons.upload_outlined,
              size: 32,
              color: hasFile ? Colors.green : const Color(0xFF8B7E3B),
            ),
            const SizedBox(height: 8),
            Text(
              hasFile ? _proofFile!.name : 'Upload Receipt/Screenshot',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: hasFile ? Colors.green.shade700 : cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comprobante de Pago',
              style: TextStyle(fontSize: 12, color: Color(0xFF8B7E3B)),
            ),
            const SizedBox(height: 14),
            if (!hasFile)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      color: cs.surface,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitProof,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4C84A),
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black54,
                  ),
                )
              : const Text(
                  'Submit Proof',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
