/// Wrapper for the Home endpoint payload.
class HomeData {
  final String message;
  final Map<String, dynamic>? data;
  
  HomeData({
    required this.message,
    this.data,
  });
  
  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}
