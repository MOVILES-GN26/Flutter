import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuración central del API
class ApiConfig {
  // Cuando el backend esté desplegado, reemplazar con la URL de AWS.
  static String get baseUrl {
    // Si es Web, usamos localhost porque el navegador corre en la msima máquina
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // 10.0.2.2 es la IP especial en el emulador de Android para acceder al localhost del PC
    if (Platform.isAndroid) {
      return 'http://10.240.234.108:3000';
    }
    // Para el simulador de iOS funciona localhost.
    // Si usas un dispositivo físico real, debes poner la IP de tu computadora (ej: http://192.168.1.10:3000)
    return 'http://localhost:3000';
  }

  /// IP del PC en la red local. Las URLs de MinIO devueltas por el backend
  /// usan IPs internas de Docker (172.x.x.x / 127.0.0.1) que no son
  /// accesibles desde Android. Esta IP es la del PC en la red Wi-Fi.
  static const String _pcLanIp = '10.240.234.108';

  /// Reemplaza hosts internos (localhost, 127.0.0.1, IPs Docker 172.x.x.x)
  /// por la IP LAN del PC para que Android pueda acceder a MinIO y al API.
  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (kIsWeb) return url;
    if (Platform.isAndroid) {
      try {
        final uri = Uri.parse(url);
        final host = uri.host;
        final isInternal = host == 'localhost' ||
            host == '127.0.0.1' ||
            host.startsWith('172.');
        if (isInternal) {
          return uri.replace(host: _pcLanIp).toString();
        }
      } catch (_) {}
    }
    return url;
  }

  // Endpoints disponibles
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
  static const String favoritesEndpoint = '/users/me/favorites';
  static String favoriteCountEndpoint(String productId) =>
      '/products/$productId/favorites/count';
  static String interactionsStatsEndpoint(String productId) =>
      '/interactions/product/$productId/stats';
  static String orderEndpoint(String orderId) => '/orders/$orderId';
  static String orderConfirmEndpoint(String orderId) =>
      '/orders/$orderId/confirm';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Headers comunes
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
}
