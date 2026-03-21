import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    required String phoneNumber,
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
          'phone_number': phoneNumber,
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
    String? storeId,
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
      if (storeId != null) {
        request.fields['store_id'] = storeId;
      }

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

      if (streamedResponse.statusCode != 200 &&
          streamedResponse.statusCode != 201) {
        final body = await streamedResponse.stream.bytesToString();
        debugPrint('[createPost] failed ${streamedResponse.statusCode}: $body');
      }

      return streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201;
    } catch (e) {
      debugPrint('[createPost] exception: $e');
      return false;
    }
  }

  /// Fetch the top trending categories of the last 7 days.
  Future<List<String>> getTrendingCategories() async {
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.trendingCategoriesEndpoint}');
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => e['category'] as String).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch the stores owned by the authenticated user.
  Future<List<Map<String, dynamic>>> getMyStores() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return [];
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.myStoresEndpoint}');
      final response = await http
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.connectionTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Registers a view interaction for a product.
  Future<void> registerView(String productId) async {
    try {
      final token = await _storageService.getAccessToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.interactionsViewEndpoint}'),
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
        body: jsonEncode({'product_id': productId}),
      ).timeout(ApiConfig.connectionTimeout);
    } catch (e) {
      debugPrint('[registerView] exception: $e');
    }
  }

  /// Returns the stats (total views, etc.) for a product.
  Future<Map<String, dynamic>?> getProductStats(String productId) async {
    try {
      final token = await _storageService.getAccessToken();
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.interactionsStatsEndpoint(productId)}');
      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[getProductStats] exception: $e');
      return null;
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

  /// Fetch all products belonging to a specific user.
  Future<List<Listing>> getUserProducts(String userId) async {
    try {
      final token = await _storageService.getAccessToken();
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/$userId/products');
      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['items'] as List? ?? []);
        return list
            .map((json) => Listing.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[getUserProducts] exception: $e');
      return [];
    }
  }

  /// Deletes a product by ID. Returns true on success.
  Future<bool> deleteProduct(String id) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$id'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.connectionTimeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[deleteProduct] exception: $e');
      return false;
    }
  }

  /// Updates the authenticated user's profile via PATCH /users/me.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String major,
    String? password,
    String? phoneNumber,
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;

      final body = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'major': major,
      };
      if (password != null) body['password'] = password;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/me'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectionTimeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[updateProfile] exception: $e');
      return false;
    }
  }

  /// Uploads a new avatar image. Returns the new avatar URL on success.
  Future<String?> updateAvatar(File imageFile) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;

      final ext = imageFile.path.split('.').last.toLowerCase();
      final subtype =
          ['png', 'gif', 'webp'].contains(ext) ? ext : 'jpeg';

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imageFile.path,
          contentType: MediaType('image', subtype),
        ),
      );

      final streamed = await request.send().timeout(ApiConfig.connectionTimeout);
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        final data = jsonDecode(responseBody);
        return data['avatar_url'] as String? ?? data['url'] as String?;
      }
      debugPrint('[updateAvatar] failed ${streamed.statusCode}: $responseBody');
      return null;
    } catch (e) {
      debugPrint('[updateAvatar] exception: $e');
      return null;
    }
  }

  /// Creates an order for a product.
  Future<Map<String, dynamic>?> createOrder({
    required String productId,
    required int quantity,
    String? deliveryOption,
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;

      final body = <String, dynamic>{
        'product_id': productId,
        'quantity': quantity,
      };
      if (deliveryOption != null) body['delivery_option'] = deliveryOption;

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ordersEndpoint}'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[createOrder] failed ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[createOrder] exception: $e');
      return null;
    }
  }

  /// Uploads a payment proof image (as bytes) for the given order.
  Future<Map<String, dynamic>?> uploadPaymentProof(
    String orderId,
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;

      final ext = fileName.split('.').last.toLowerCase();
      final subtype =
          ['png', 'gif', 'webp'].contains(ext) ? ext : 'jpeg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.ordersEndpoint}/$orderId/upload-proof'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', subtype),
        ),
      );

      final streamed =
          await request.send().timeout(ApiConfig.connectionTimeout);
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      debugPrint(
          '[uploadPaymentProof] failed ${streamed.statusCode}: $responseBody');
      return null;
    } catch (e) {
      debugPrint('[uploadPaymentProof] exception: $e');
      return null;
    }
  }
}
