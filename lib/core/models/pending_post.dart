/// A post that the user submitted while offline (or whose upload failed).
/// Lives in the Hive `pending_posts_box` until it is successfully flushed
/// to the API, at which point it is deleted from the queue.
class PendingPost {
  final String id; // client-generated, used as Hive key
  final String title;
  final String description;
  final String category;
  final String buildingLocation;
  final double price;
  final String condition;
  final List<String> imagePaths;
  final String? storeId;
  final DateTime queuedAt;

  PendingPost({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.buildingLocation,
    required this.price,
    required this.condition,
    required this.imagePaths,
    this.storeId,
    required this.queuedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'building_location': buildingLocation,
        'price': price,
        'condition': condition,
        'image_paths': imagePaths,
        if (storeId != null) 'store_id': storeId,
        'queued_at': queuedAt.toIso8601String(),
      };

  factory PendingPost.fromMap(Map<String, dynamic> m) => PendingPost(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        category: m['category'] as String,
        buildingLocation: m['building_location'] as String,
        price: (m['price'] as num).toDouble(),
        condition: m['condition'] as String,
        imagePaths: List<String>.from(m['image_paths'] ?? const []),
        storeId: m['store_id'] as String?,
        queuedAt: DateTime.parse(m['queued_at'] as String),
      );
}
