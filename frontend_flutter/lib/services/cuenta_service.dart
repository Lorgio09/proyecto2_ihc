import 'dart:convert';

import 'package:http/http.dart' as http;

import '../consts/api_url.dart';
import 'auth_service.dart';
import 'descarga.dart';

/// The deletion was stopped by UniSport's rule; each block says why and what
/// to do.
class CuentaBloqueada implements Exception {
  CuentaBloqueada(this.bloqueos);

  final List<Map<String, dynamic>> bloqueos;
}

/// "Mi cuenta": the person's own data (see and download it) and the way to
/// delete the account.
class CuentaService {
  final http.Client client = http.Client();
  final TokenStorage storage = SecureTokenStorage();

  Future<Map<String, String>> headers() async {
    final token = await storage.read();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri url(String ruta) => Uri.parse('$apiBaseUrl/api/cuenta$ruta');

  Future<Map<String, dynamic>> misDatos() async {
    final respuesta = await client.get(
      url('/mis-datos'),
      headers: await headers(),
    );
    if (respuesta.statusCode != 200) {
      throw Exception('No se pudieron cargar tus datos');
    }
    return jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  }

  /// What deleting the account would do, or what stops it.
  Future<Map<String, dynamic>> antesDeEliminar() async {
    final respuesta = await client.get(
      url('/eliminacion'),
      headers: await headers(),
    );
    if (respuesta.statusCode != 200) {
      throw Exception('No se pudo revisar tu cuenta');
    }
    return jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  }

  /// Deletes the account and forgets the session stored on the phone.
  Future<void> eliminarCuenta() async {
    final respuesta = await client.delete(url(''), headers: await headers());
    if (respuesta.statusCode == 409) {
      final detalle =
          jsonDecode(utf8.decode(respuesta.bodyBytes))['detail']
              as Map<String, dynamic>;
      throw CuentaBloqueada(
        (detalle['bloqueos'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (respuesta.statusCode != 204) {
      throw Exception('No se pudo eliminar la cuenta');
    }
    await storage.delete();
  }

  /// Saves [contenido] in the device's Downloads folder (or as a browser
  /// download on the web) and returns where it went.
  Future<String> guardarEnDescargas(String nombre, String contenido) =>
      guardarArchivo(nombre, contenido);

  /// Analytics, same endpoint as the rest of the app. Never breaks anything.
  Future<void> registrarEvento(
    String evento, {
    Map<String, Object> props = const {},
  }) async {
    try {
      await client.post(
        Uri.parse('$apiBaseUrl/api/analitica/eventos'),
        headers: await headers(),
        body: jsonEncode({'evento': evento, 'props': props}),
      );
    } catch (_) {}
  }
}
