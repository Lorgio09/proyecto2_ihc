class Usuario {
  final int id;
  final String nombre;
  final String email;

  const Usuario({required this.id, required this.nombre, required this.email});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final Usuario usuario;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.usuario,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegistroRequest {
  final String nombre;
  final String email;
  final String password;
  final String? telefono;

  const RegistroRequest({
    required this.nombre,
    required this.email,
    required this.password,
    this.telefono,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'email': email,
    'password': password,
    'telefono': telefono,
  };
}
