import 'dart:convert';

import 'package:http/http.dart' as http;

import '../consts/api_url.dart';
import '../models/partido.dart';
import 'auth_service.dart';

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

  Future<List<Partido>> listar() async {
    final response = await client.get(url(''), headers: await headers());

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los partidos');
    }

    final lista = jsonDecode(response.body) as List;

    return lista.map((partido) => Partido.fromJson(partido)).toList();
  }

  Future<Partido> crear(PartidoCreateRequest datos) async {
    final response = await client.post(
      url(''),
      headers: await headers(),
      body: jsonEncode(datos.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception('No se pudo crear el partido');
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
      throw Exception('No se pudo actualizar el partido');
    }

    return Partido.fromJson(jsonDecode(response.body));
  }

  Future<void> eliminar(int id) async {
    final response = await client.delete(url('/$id'), headers: await headers());

    if (response.statusCode != 204) {
      throw Exception('No se pudo eliminar el partido');
    }
  }

  Future<Partido> completarEquipo(int id) async {
    final response = await client.patch(
      url('/$id/completar'),
      headers: await headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo completar el equipo');
    }

    return Partido.fromJson(
      jsonDecode(response.body),
    );
  }
}
