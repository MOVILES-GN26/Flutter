/// Central API configuration.
class ApiConfig {
  static const String _productionUrl = 'https://andeshub.vrm.software';

  /// Always points to production. Web uses it for quick testing without
  /// needing a local server. Native (Android/iOS) uses it normally.
  static String get baseUrl => _productionUrl;

  // Available endpoints
  static const String homeEndpoint = '/home';
  static const String refreshEndpoint = '/refresh';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String postsEndpoint = '/posts';
  static const String productsEndpoint = '/products';
  static const String usersEndpoint = '/users';
  static const String ordersEndpoint = '/orders';
  static const String trendingCategoriesEndpoint = '/trending/categories';
  static const String myStoresEndpoint = '/stores/my-stores';
  static const String interactionsViewEndpoint = '/interactions/view';
  static const String analyticsContactEndpoint = '/analytics/contact';
  static const String favoritesEndpoint = '/users/me/favorites';
  static const String viewedCategoryEndpoint = '/interactions/viewed-category';
  static const String recommendedProductsEndpoint = '/products/recommended';
  static String favoriteCountEndpoint(String productId) =>
      '/products/$productId/favorites/count';
  static String interactionsStatsEndpoint(String productId) =>
      '/interactions/product/$productId/stats';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Common headers
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
}
