import 'dart:convert';
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
