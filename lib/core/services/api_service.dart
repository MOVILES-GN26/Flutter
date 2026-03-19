import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'storage_service.dart';
import '../models/listing.dart';

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

      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
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
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['building_location'] = buildingLocation;
      request.fields['price'] = price.toString();
      request.fields['condition'] = condition;

      for (final image in images) {
        final ext = image.path.split('.').last.toLowerCase();
        final subtype = (ext == 'png' || ext == 'gif' || ext == 'webp') ? ext : 'jpeg';
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
            contentType: MediaType('image', subtype),
          ),
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
  }

  /// Fetch the most recent listings for the Home screen.
  Future<List<Listing>> getRecentProducts() async {
    try {
      final data = await getProducts();
      return data.map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
