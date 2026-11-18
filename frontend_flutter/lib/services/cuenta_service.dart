import 'dart:convert';

import 'package:http/http.dart' as http;

import '../consts/api_url.dart';
import 'auth_service.dart';
import 'descarga.dart';

/// La regla de UniSport detuvo la eliminación; cada bloqueo dice por qué y qué
/// hacer.
class CuentaBloqueada implements Exception {
  CuentaBloqueada(this.bloqueos);

  final List<Map<String, dynamic>> bloqueos;
}

/// "Mi cuenta": los datos propios de la persona (verlos y descargarlos) y la
/// forma de eliminar la cuenta.
class CuentaService {
  /// El cliente y el almacenamiento del token se pueden reemplazar en las
  /// pruebas; la app usa los valores por defecto.
  CuentaService({http.Client? client, TokenStorage? storage})
    : client = client ?? http.Client(),
      storage = storage ?? SecureTokenStorage();

  final http.Client client;
  final TokenStorage storage;

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

  /// Qué haría eliminar la cuenta, o qué lo impide.
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

  /// Elimina la cuenta y olvida la sesión guardada en el teléfono.
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

  /// Guarda [contenido] en la carpeta Descargas del dispositivo (o como
  /// descarga del navegador en la web) y devuelve dónde quedó.
  Future<String> guardarEnDescargas(String nombre, String contenido) =>
      guardarArchivo(nombre, contenido);

  /// Analítica, mismo endpoint que el resto de la app. Nunca rompe nada.
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
