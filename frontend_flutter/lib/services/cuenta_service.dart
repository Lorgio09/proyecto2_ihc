import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../consts/api_url.dart';
import 'auth_service.dart';

/// "Mi cuenta": the person's own data (see and download it).
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

  /// Saves [contenido] in the device's Downloads folder and returns the path.
  Future<String> guardarEnDescargas(String nombre, String contenido) async {
    final carpeta = _carpetaDescargas();
    await carpeta.create(recursive: true);
    final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
    await archivo.writeAsString(contenido);
    return archivo.path;
  }

  Directory _carpetaDescargas() {
    // Android 11+ lets an app create its own files in the shared Downloads
    // folder without asking for any permission.
    if (Platform.isAndroid) return Directory('/storage/emulated/0/Download');
    final inicio =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (inicio != null)
      return Directory('$inicio${Platform.pathSeparator}Downloads');
    return Directory.systemTemp;
  }

  /// Analytics, same endpoint as the rest of the app. Never breaks anything.
  Future<void> registrarEvento(String evento) async {
    try {
      await client.post(
        Uri.parse('$apiBaseUrl/api/analitica/eventos'),
        headers: await headers(),
        body: jsonEncode({'evento': evento, 'props': {}}),
      );
    } catch (_) {}
  }
}
