import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../../features/home/models/home_item.dart';

/// Servicio central para peticiones HTTP al API
class ApiService {
  final StorageService _storageService = StorageService();
  
  /// Petición GET a /home con el access token
  Future<bool> validateHomeAccess() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.homeEndpoint}'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.connectionTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Intenta refrescar el token usando el refresh token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) return false;
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refreshEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(ApiConfig.connectionTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storageService.saveAccessToken(data['access_token']);
        if (data.containsKey('refresh_token')) {
          await _storageService.saveRefreshToken(data['refresh_token']);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Login del usuario
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(ApiConfig.connectionTimeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }


  /// Request a password reset email
  Future<bool> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.forgotPasswordEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'email': email}),
      ).timeout(ApiConfig.connectionTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Registro de nuevo usuario
  Future<Map<String, dynamic>?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String major,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'major': major,
          'password': password,
        }),
      ).timeout(ApiConfig.connectionTimeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      // Return error message from API if available
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch the list of products from the catalog.
  /// Supports optional query parameters for search and filtering.
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? category,
    String? condition,
    String? priceSort,
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (condition != null && condition.isNotEmpty) queryParams['condition'] = condition;
      if (priceSort != null && priceSort.isNotEmpty) queryParams['price_sort'] = priceSort;

      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data['items'] is List) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Create a new marketplace listing, uploading images as multipart.
  Future<bool> createPost({
    required String title,
    required String description,
    required String category,
    required String buildingLocation,
    required double price,
    required String condition,
    required List<File> images,
  }) async {
    try {
      final token = await _storageService.getAccessToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.postsEndpoint}'),
      );

      if (token != null) {
        request.headers.addAll(ApiConfig.authHeaders(token));
      }

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['building_location'] = buildingLocation;
      request.fields['price'] = price.toString();
      request.fields['condition'] = condition;

      for (final image in images) {
        request.files.add(
          await http.MultipartFile.fromPath('images', image.path),
        );
      }

      final streamedResponse = await request.send().timeout(
            ApiConfig.connectionTimeout,
          );

      return streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201;
    } catch (e) {
      return false;
    }

  
  /// Obtener items del home (Recently Added)
  Future<List<HomeItem>> getHomeItems() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) {
        // TODO: Remover esto cuando el backend esté funcionando
        // Datos de prueba temporales
        return _getMockHomeItems();
      }
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.homeEndpoint}'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.connectionTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>?;
        
        if (items != null && items.isNotEmpty) {
          return items.map((item) => HomeItem.fromJson(item)).toList();
        }
      }
      
      // TODO: Remover esto cuando el backend esté funcionando
      // Si falla o no hay items, retornar datos de prueba
      return _getMockHomeItems();
    } catch (e) {
      // TODO: Remover esto cuando el backend esté funcionando
      // En caso de error, retornar datos de prueba
      return _getMockHomeItems();
    }
  }
  
  /// TODO: REMOVER ESTE MÉTODO cuando el backend esté funcionando
  /// Datos de prueba temporales para el diseño
  List<HomeItem> _getMockHomeItems() {
    return [
      HomeItem(
        id: '1',
        title: 'Calculus Textbook',
        price: 50.0,
        imageUrl: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400',
        description: 'Calculus textbook in good condition',
      ),
      HomeItem(
        id: '2',
        title: 'MacBook Pro',
        price: 1200.0,
        imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400',
        description: 'MacBook Pro 2020 model',
      ),
      HomeItem(
        id: '3',
        title: 'Apartment near campus',
        price: 800.0,
        imageUrl: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400',
        description: 'Apartment 2 blocks from campus',
      ),
    ];

  }
}
