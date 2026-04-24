import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure key/value store backed by Keychain (iOS) / EncryptedSharedPreferences
/// (Android). Use for secrets ONLY: auth tokens and the last-used login email
/// (which is considered an account identifier).
///
/// Non-sensitive settings should go to [PreferencesService] instead.
class StorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ── Keys ──────────────────────────────────────────────────────────────
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _lastLoginEmailKey = 'last_login_email';

  // ── Access token ──────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);

  // ── Refresh token ─────────────────────────────────────────────────────

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshTokenKey);

  /// Clears both tokens. Keeps [lastLoginEmail] in place so returning users
  /// still get their email prefilled on the login screen.
  Future<void> clearAllTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> hasTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    return access != null || refresh != null;
  }

  // ── Last-login email ──────────────────────────────────────────────────

  /// Returns the email used on the last successful login, if any.
  /// Used to pre-fill the login form for returning users.
  Future<String?> getLastLoginEmail() =>
      _storage.read(key: _lastLoginEmailKey);

  Future<void> saveLastLoginEmail(String email) =>
      _storage.write(key: _lastLoginEmailKey, value: email);

  Future<void> deleteLastLoginEmail() =>
      _storage.delete(key: _lastLoginEmailKey);

  /// Wipes EVERYTHING in secure storage, including [lastLoginEmail].
  /// Only use when the user explicitly wants to erase all trace of prior
  /// sessions (e.g. a "forget this device" option). Regular logouts should
  /// use [clearAllTokens] to keep the login-email prefill convenience.
  Future<void> wipe() => _storage.deleteAll();
}
