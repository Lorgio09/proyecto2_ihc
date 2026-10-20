import 'dart:convert';

import 'package:http/http.dart' as http;

import '../consts/api_url.dart';
import '../models/partido.dart';
import 'auth_service.dart';

import '../models/historial_partido.dart';

class PartidoError implements Exception {
  final String codigo;
  final String mensaje;

  const PartidoError({required this.codigo, required this.mensaje});

  @override
  String toString() => mensaje;
}

class PartidoService {
  final http.Client client = http.Client();
  final TokenStorage storage = SecureTokenStorage();

  Future<Map<String, String>> headers() async {
    final token = await storage.read();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri url(String ruta) => Uri.parse('$apiBaseUrl/api/partidos$ruta');

  Exception errorRespuesta(http.Response respuesta, String mensaje) {
    try {
      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final detalle = cuerpo['detail'];
      if (detalle is Map<String, dynamic>) {
        return PartidoError(
          codigo: detalle['codigo'] as String? ?? 'ERROR',
          mensaje: detalle['mensaje'] as String? ?? mensaje,
        );
      }
    } catch (_) {}

    return Exception(mensaje);
  }

  Future<List<Partido>> listar() async {
    final response = await client.get(url(''), headers: await headers());

    if (response.statusCode != 200) {
      throw errorRespuesta(response, 'No se pudieron cargar tus partidos');
    }

    final lista = jsonDecode(response.body) as List;

    return lista.map((partido) => Partido.fromJson(partido)).toList();
  }

  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async {
    final parametros = <String, String>{};

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      parametros['busqueda'] = busqueda.trim();
    }
    if (deporte != null && deporte.isNotEmpty) parametros['deporte'] = deporte;
    if (zona != null && zona.trim().isNotEmpty) {
      parametros['zona'] = zona.trim();
    }
    if (desde != null) {
      parametros['desde'] = desde.toIso8601String().substring(0, 10);
    }
    if (hasta != null) {
      parametros['hasta'] = hasta.toIso8601String().substring(0, 10);
    }
    if (soloConCupos) parametros['solo_con_cupos'] = 'true';

    final respuesta = await client.get(
      url('/explorar').replace(queryParameters: parametros),
      headers: await headers(),
    );

    if (respuesta.statusCode != 200) {
      throw errorRespuesta(respuesta, 'No se pudieron cargar los partidos');
    }

    final lista = jsonDecode(respuesta.body) as List;
    return lista.map((partido) => Partido.fromJson(partido)).toList();
  }

  Future<Partido> crear(PartidoCreateRequest datos) async {
    final response = await client.post(
      url(''),
      headers: await headers(),
      body: jsonEncode(datos.toJson()),
    );

    if (response.statusCode != 201) {
      throw errorRespuesta(response, 'No se pudo crear el partido');
    }

    return Partido.fromJson(jsonDecode(response.body));
  }

  Future<Partido> actualizar(int id, PartidoUpdateRequest datos) async {
    final response = await client.put(
      url('/$id'),
      headers: await headers(),
      body: jsonEncode(datos.toJson()),
    );

    if (response.statusCode != 200) {
      throw errorRespuesta(response, 'No se pudo actualizar el partido');
    }

    return Partido.fromJson(jsonDecode(response.body));
  }

  Future<void> eliminar(int id) async {
    final response = await client.delete(url('/$id'), headers: await headers());

    if (response.statusCode != 204) {
      throw errorRespuesta(response, 'No se pudo eliminar el partido');
    }
  }

  Future<Partido> completarEquipo(int id) async {
    final response = await client.patch(
      url('/$id/completar'),
      headers: await headers(),
    );

    if (response.statusCode != 200) {
      throw errorRespuesta(response, 'No se pudo completar el equipo');
    }

    return Partido.fromJson(jsonDecode(response.body));
  }

  Future<Partido> unirse(int id) async {
    final respuesta = await client.post(
      url('/$id/unirse'),
      headers: await headers(),
    );

    if (respuesta.statusCode != 200) {
      throw errorRespuesta(respuesta, 'No se pudo unir al partido');
    }

    return Partido.fromJson(jsonDecode(respuesta.body));
  }

  Future<Partido> salir(int id) async {
    final respuesta = await client.delete(
      url('/$id/salir'),
      headers: await headers(),
    );

    if (respuesta.statusCode != 200) {
      throw errorRespuesta(respuesta, 'No se pudo salir del partido');
    }

    return Partido.fromJson(jsonDecode(respuesta.body));
  }

  Future<Partido> reabrir(int id) async {
    final respuesta = await client.patch(
      url('/$id/reabrir'),
      headers: await headers(),
    );

    if (respuesta.statusCode != 200) {
      throw errorRespuesta(respuesta, 'No se pudo reabrir el equipo');
    }

    return Partido.fromJson(jsonDecode(respuesta.body));
  }

  Future<List<HistorialPartido>> listarHistorial() async {
    final respuesta = await client.get(
      url('/historial'),
      headers: await headers(),
    );

    if (respuesta.statusCode != 200) {
      throw errorRespuesta(respuesta, 'No se pudo cargar el historial');
    }

    final lista = jsonDecode(respuesta.body) as List;

    return lista
        .map(
          (elemento) =>
              HistorialPartido.fromJson(elemento as Map<String, dynamic>),
        )
        .toList();
  }
}
