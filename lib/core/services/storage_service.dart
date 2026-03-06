import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para manejo de almacenamiento seguro
class StorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  
  // Access Token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }
  
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }
  
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
  
  // Refresh Token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }
  
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }
  
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }
  
  // Limpiar todos los tokens
  Future<void> clearAllTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
  
  // Verificar si hay tokens guardados
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null || refreshToken != null;
  }
}
