/// Configuración central del API
class ApiConfig {
  // TODO: Cambiar a la URL real cuando el backend esté desplegado
  static const String baseUrl = 'http://localhost:3000';
  
  // Endpoints disponibles
  static const String homeEndpoint = '/home';
  static const String refreshEndpoint = '/refresh';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String postsEndpoint = '/posts';
  static const String productsEndpoint = '/products';
  static const String usersEndpoint = '/users';
  
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
