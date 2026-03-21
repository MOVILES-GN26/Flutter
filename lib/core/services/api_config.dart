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
      return 'http://10.0.2.2:3000';
    }
    // Para el simulador de iOS funciona localhost.
    // Si usas un dispositivo físico real, debes poner la IP de tu computadora (ej: http://192.168.1.10:3000)
    return 'http://localhost:3000';
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
  static const String trendingCategoriesEndpoint = '/trending/categories';
  static const String myStoresEndpoint = '/stores/my-stores';
  static const String interactionsViewEndpoint = '/interactions/view';
  static String interactionsStatsEndpoint(String productId) =>
      '/interactions/product/$productId/stats';
  
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
