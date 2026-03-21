/// Domain model representing a created order returned by the backend.
class OrderModel {
  final String id;
  final String productId;
  final int quantity;
  final double total;
  final String? deliveryOption;
  final String status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.total,
    this.deliveryOption,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      deliveryOption: json['delivery_option'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
