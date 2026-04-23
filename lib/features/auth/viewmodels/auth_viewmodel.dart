import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/hive_service.dart';
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
  bool _forgotPasswordSuccess = false;

  AuthViewModel() {
    // Hydrate from the Hive cache so UI bound to `user` has data before
    // any login happens (useful when tokens are still valid from a prior session).
    _user = HiveService.getUser();
  }
  
  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get forgotPasswordSuccess => _forgotPasswordSuccess;

  /// The email used on the last successful login, or null if never logged in.
  /// Consumed by the Login view to pre-fill the email field.
  Future<String?> getLastLoginEmail() => _storageService.getLastLoginEmail();
  
  /// Perform login against the API.
  /// Shows specific error messages so the user knows what went wrong.
  Future<void> login(
    String email,
    String password, {
    String loginType = 'email-password',
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _apiService.login(email, password, loginType: loginType);
      
      if (response != null && response['access_token'] != null) {
        await _storageService.saveAccessToken(response['access_token']);
        if (response['refresh_token'] != null) {
          await _storageService.saveRefreshToken(response['refresh_token']);
        }
        // Remember the email so the login view can pre-fill it next time.
        await _storageService.saveLastLoginEmail(email);

        if (response['user'] != null) {
          _user = AuthUser.fromJson(response['user']);
          await HiveService.putUser(_user!);
        }

        _status = AuthStatus.authenticated;
      } else {
        _errorMessage = 'Incorrect email or password. Please check and try again.';
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
      _status = AuthStatus.unauthenticated;
    }
    
    notifyListeners();
  }
  
  /// Request a password reset email for the given address.
  Future<void> forgotPassword(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _forgotPasswordSuccess = false;
    notifyListeners();
    
    try {
      final success = await _apiService.forgotPassword(email);
      
      if (success) {
        _forgotPasswordSuccess = true;
      } else {
        _errorMessage =
            'Could not send reset email. Please verify your email address and try again.';
      }
    } catch (e) {
      _errorMessage =
          'Unable to connect to the server. Please check your internet connection and try again.';
    }
    
    _status = AuthStatus.initial;
    notifyListeners();
  }

  /// Reset forgot password state when navigating away
  void resetForgotPasswordState() {
    _forgotPasswordSuccess = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Registrar nuevo usuario
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String major,
    required String password,
    required String phoneNumber,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        major: major,
        password: password,
        phoneNumber: phoneNumber,
      );
      
      if (response != null && response['access_token'] != null) {
        await _storageService.saveAccessToken(response['access_token']);
        if (response['refresh_token'] != null) {
          await _storageService.saveRefreshToken(response['refresh_token']);
        }
        await _storageService.saveLastLoginEmail(email);

        if (response['user'] != null) {
          _user = AuthUser.fromJson(response['user']);
          await HiveService.putUser(_user!);
        }

        _status = AuthStatus.authenticated;
      } else {
        _errorMessage = response?['message'] ?? 'Registration failed';
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      // Network or server error — the backend may be unreachable
      _errorMessage =
          'Unable to connect to the server. Please check your internet connection and try again.';
      _status = AuthStatus.unauthenticated;
    }
    
    notifyListeners();
  }

  /// Cerrar sesión. Wipes both token storage and the cached user/favorites
  /// in Hive so the next account that logs in starts from a clean slate.
  Future<void> logout() async {
    await _storageService.clearAllTokens();
    await HiveService.clearUser();
    await HiveService.clearFavorites();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
