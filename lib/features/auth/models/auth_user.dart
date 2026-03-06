/// Modelo para el usuario autenticado
class AuthUser {
  final String id;
  final String email;
  final String? name;
  
  AuthUser({
    required this.id,
    required this.email,
    this.name,
  });
  
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
    };
  }
}
