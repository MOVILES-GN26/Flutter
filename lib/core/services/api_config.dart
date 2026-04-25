import 'dart:io';
import 'package:flutter/foundation.dart';

/// Central API configuration.
class ApiConfig {
  // Replace with the AWS URL once the backend is deployed.
  static String get baseUrl {
    // On Web, use localhost: the browser runs on the same machine as the API.
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // 10.0.2.2 is the Android emulator's special alias to the host machine.
    if (Platform.isAndroid) {
      return 'http://192.168.0.100:3000';
    }
    // The iOS simulator can reach the host via localhost.
    // For a physical device, use the host computer's LAN IP (e.g. http://192.168.1.10:3000).
    return 'http://localhost:3000';
  }

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
