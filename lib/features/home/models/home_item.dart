/// Modelo para un item del home (Recently Added)
class HomeItem {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final String? description;
  
  HomeItem({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.description,
  });
  
  factory HomeItem.fromJson(Map<String, dynamic> json) {
    return HomeItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      description: json['description'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'image_url': imageUrl,
      'description': description,
    };
  }
}
