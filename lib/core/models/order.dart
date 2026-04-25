/// Domain model for a marketplace order.
import '../services/api_config.dart';

class Order {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final int quantity;
  final double total;
  final String status;
  final String? deliveryOption;
  final String? paymentProofUrl;
  final Map<String, dynamic>? buyer;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.quantity,
    required this.total,
    required this.status,
    this.deliveryOption,
    this.paymentProofUrl,
    this.buyer,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      deliveryOption: json['delivery_option'] as String?,
      paymentProofUrl: ApiConfig.fixImageUrl(
          (json['payment_proof_url'])?.toString()),
      buyer: json['buyer'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Returns true if the buyer has uploaded payment proof.
  bool get isPaymentUploaded => status == 'payment_uploaded';

  /// Returns true if the seller has confirmed the payment.
  bool get isConfirmed => status == 'confirmed';

  /// Returns true if the order is still pending.
  bool get isPending => status == 'pending';

  /// Human-readable label for the current status.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'payment_uploaded':
        return 'Payment Uploaded';
      case 'confirmed':
        return 'Confirmed';
      case 'shipping':
        return 'Shipping';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Phone number of the buyer (from the joined buyer relation).
  String get buyerPhone =>
      (buyer?['phone_number'] as String?) ?? '';

  /// Display name of the buyer.
  String get buyerName {
    if (buyer == null) return 'Buyer';
    final name = buyer!['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final first = buyer!['first_name'] as String? ?? '';
    final last = buyer!['last_name'] as String? ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Buyer';
  }
}
