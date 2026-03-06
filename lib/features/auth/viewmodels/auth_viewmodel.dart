import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/auth_user.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

/// ViewModel para manejo de autenticación
class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  AuthStatus _status = AuthStatus.initial;
  AuthUser? _user;
  String? _errorMessage;
  
  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  
  /// Realizar login
  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _apiService.login(email, password);
      
      if (response != null && response['access_token'] != null) {
        await _storageService.saveAccessToken(response['access_token']);
        if (response['refresh_token'] != null) {
          await _storageService.saveRefreshToken(response['refresh_token']);
        }
        
        if (response['user'] != null) {
          _user = AuthUser.fromJson(response['user']);
        }
        
        _status = AuthStatus.authenticated;
      } else {
        _errorMessage = 'Credenciales inválidas';
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión';
      _status = AuthStatus.unauthenticated;
    }
    
    notifyListeners();
  }
  
  /// Cerrar sesión
  Future<void> logout() async {
    await _storageService.clearAllTokens();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
