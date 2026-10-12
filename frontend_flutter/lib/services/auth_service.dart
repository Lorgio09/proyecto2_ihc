import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../consts/api_url.dart';
import '../models/usuario.dart';

abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStorage implements TokenStorage {
  static const _storageKey = 'access_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _storageKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _storageKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _storageKey);
}

class AuthService {
  AuthService({http.Client? client, TokenStorage? storage, String? baseUrl})
    : _client = client ?? http.Client(),
      _storage = storage ?? SecureTokenStorage(),
      _baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final TokenStorage _storage;
  final String _baseUrl;

  Future<Usuario> login(String email, String password) async {
    final body = LoginRequest(email: email, password: password).toJson();
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return _guardarRespuestaAuth(response, 200);
  }

  Future<Usuario> registro(
    String nombre,
    String email,
    String password,
    String? telefono,
  ) async {
    final body = RegistroRequest(
      nombre: nombre,
      email: email,
      password: password,
      telefono: telefono,
    ).toJson();
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return _guardarRespuestaAuth(response, 201);
  }

  Future<Usuario> _guardarRespuestaAuth(
    http.Response response,
    int codigoEsperado,
  ) async {
    if (response.statusCode != codigoEsperado) {
      throw Exception(obtener_mensaje_error(response.body));
    }

    final authResponse = AuthResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _storage.write(authResponse.accessToken);
    return authResponse.usuario;
  }

  Future<String> recuperarPassword(String email) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/recuperar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception(obtener_mensaje_error(response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['token'] as String;
  }

  Future<void> cambiarPassword(String token, String nuevaPassword) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/cambiar-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'nueva_password': nuevaPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception(obtener_mensaje_error(response.body));
    }
  }

  Future<void> cambiarPasswordAutenticado(
    String contrasenaActual,
    String nuevaPassword,
  ) async {
    final token = await _storage.read();
    if (token == null || token.isEmpty) {
      throw Exception('La sesión ha expirado');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/cambiar-password-auth'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'contrasena_actual': contrasenaActual,
        'nueva_password': nuevaPassword,
      }),
    );

    if (response.statusCode == 401) {
      await _storage.delete();
    }
    if (response.statusCode != 200) {
      throw Exception(obtener_mensaje_error(response.body));
    }
  }

  Future<Usuario?> currentUser() async {
    final token = await _storage.read();
    if (token == null || token.isEmpty) return null;

    final response = await _client.get(
      Uri.parse('$_baseUrl/api/auth/yo'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      await _storage.delete();
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception(obtener_mensaje_error(response.body));
    }

    return Usuario.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> logout() => _storage.delete();

  String obtener_mensaje_error(String cuerpo) {
    try {
      final json = jsonDecode(cuerpo) as Map<String, dynamic>;
      return json['detail']?.toString() ?? 'Ocurrió un error';
    } catch (_) {
      return 'Ocurrió un error';
    }
  }
}
