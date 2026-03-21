import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen shown after the payment proof has been submitted successfully.
class OrderSuccessView extends StatefulWidget {
  final String orderId;
  final DateTime orderDate;
  final double total;
  final String productTitle;
  final String? sellerPhone;
  final String deliveryOption;

  const OrderSuccessView({
    super.key,
    required this.orderId,
    required this.orderDate,
    required this.total,
    required this.productTitle,
    this.sellerPhone,
    required this.deliveryOption,
  });

  @override
  State<OrderSuccessView> createState() => _OrderSuccessViewState();
}

class _OrderSuccessViewState extends State<OrderSuccessView> {
  final TextEditingController _addressController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String get _shortOrderId =>
      '#${widget.orderId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _openWhatsApp() async {
    final phone = widget.sellerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller phone number not available.')),
      );
      return;
    }

    final address = _addressController.text.trim();
    final String message;
    if (widget.deliveryOption == 'shipping' && address.isNotEmpty) {
      message =
          'Hi! I purchased "${widget.productTitle}" (Order $_shortOrderId). '
          'Please deliver to: $address';
    } else {
      message =
          'Hi! I purchased "${widget.productTitle}" (Order $_shortOrderId). '
          'When can we coordinate the pickup at the university?';
    }

    final encodedMsg = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$encodedMsg');

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
    final isShipping = widget.deliveryOption == 'shipping';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        centerTitle: true,
        title: const Text(
          'Order Successful',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Checkmark banner ──
            _buildCheckmarkBanner(),
            const SizedBox(height: 20),

            // ── Payment Verified ──
            const Center(
              child: Text(
                'Payment Verified!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Order Summary ──
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(height: 20, color: Color(0xFFEEECE0)),
            Row(
              children: [
                Expanded(
                  child: _summaryField('Order ID', _shortOrderId),
                ),
                Expanded(
                  child: _summaryField('Date', _formatDate(widget.orderDate)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _summaryField(
                'Total', '\$${widget.total.toStringAsFixed(2)}'),
            const SizedBox(height: 24),

            // ── Delivery Option ──
            const Text(
              'Delivery Option',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            if (isShipping) ...[
              // Address input
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Enter Delivery Address',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0AEA0),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0DDD0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0DDD0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4C84A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Pickup / WhatsApp row ──
            _buildWhatsAppSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckmarkBanner() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF5ECCF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.check,
          size: 90,
          color: Color(0xFF3D7C5C),
        ),
      ),
    );
  }

  Widget _summaryField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8B7E3B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup at University?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Contact via WhatsApp',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8B7E3B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _openWhatsApp,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/whatsapp.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.chat,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
