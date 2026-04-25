/// Modelo para el usuario autenticado
class AuthUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? major;
  final String? avatarUrl;
  
  AuthUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.major,
    this.avatarUrl,
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
      avatarUrl: json['avatar_url'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'major': major,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
