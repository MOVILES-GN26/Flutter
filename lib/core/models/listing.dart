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
  final DateTime? createdAt;

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
    this.createdAt,
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
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      sellerId: seller?['id'] ?? json['seller_id'],
      sellerName: seller?['name'] ?? json['seller_name'],
      sellerMajor: seller?['major'] ?? json['seller_major'],
      sellerAvatarUrl: seller?['avatar_url'] ?? json['seller_avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
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
