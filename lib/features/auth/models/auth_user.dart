/// Modelo para el usuario autenticado
class AuthUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? major;
  
  AuthUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.major,
  });

  /// Returns the full display name, falling back gracefully if parts are missing
  String get fullName {
    final parts = [firstName, lastName].where((p) => p != null && p.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : email;
  }
  
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      major: json['major'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'major': major,
    };
  }
}
