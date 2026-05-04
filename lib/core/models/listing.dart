/// Core domain model representing a marketplace listing.
class Listing {
  final String? id;
  final String title;
  final String description;
  final String category;
  final String buildingLocation;
  final double price;
  final String? condition;
  final List<String> imageUrls;
  final String? sellerId;
  final String? sellerName;
  final String? sellerMajor;
  final String? sellerAvatarUrl;
  final String? sellerPhone;
  final DateTime? createdAt;
  /// True when the product has been sold. Hidden from Home and Favorites.
  final bool isSold;

  Listing({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.buildingLocation,
    required this.price,
    this.condition,
    this.imageUrls = const [],
    this.sellerId,
    this.sellerName,
    this.sellerMajor,
    this.sellerAvatarUrl,
    this.sellerPhone,
    this.createdAt,
    this.isSold = false,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    return Listing(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      buildingLocation: json['building_location'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      condition: json['condition'],
      imageUrls: (json['image_urls'] as List<dynamic>? ?? [])
          .map((u) => _fixImageUrl(u as String))
          .toList(),
      sellerId: seller?['id'] ?? json['seller_id'],
      sellerName: seller?['name'] ?? json['seller_name'],
      sellerMajor: seller?['major'] ?? json['seller_major'],
      sellerAvatarUrl: seller?['avatar_url'] ?? json['seller_avatar_url'],
      sellerPhone: seller?['phone_number'] ?? json['seller_phone'],
      isSold: json['is_sold'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  /// Replaces a localhost origin (any port) with the production server.
  /// Needed because the backend incorrectly returns localhost URLs in some
  /// environments. Safe to call on already-correct URLs.
  static String _fixImageUrl(String url) {
    return url.replaceFirst(
      RegExp(r'http://localhost:\d+'),
      'https://andeshub.vrm.software',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'category': category,
      'building_location': buildingLocation,
      'price': price,
      if (condition != null) 'condition': condition,
      'image_urls': imageUrls,
    };
  }
}
