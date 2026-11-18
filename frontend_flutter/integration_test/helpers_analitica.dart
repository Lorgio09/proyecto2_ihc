// Revisiones de analítica para las pruebas E2E: leen los conteos de eventos de
// la API antes y después de un flujo y los comparan.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/consts/api_url.dart';
import 'package:http/http.dart' as http;

Future<Map<String, int>> conteoEventos() async {
  final respuesta = await http.get(
    Uri.parse('$apiBaseUrl/api/analitica/resumen'),
  );
  final conteos = jsonDecode(respuesta.body)['conteos'] as Map<String, dynamic>;
  return conteos.map((evento, cantidad) => MapEntry(evento, cantidad as int));
}

/// Espera que cada evento de [esperados] haya crecido esa cantidad desde
/// [antes]. La app envía los eventos de inicio en segundo plano, así que espera
/// un poco.
Future<void> expectEventos(
  Map<String, int> antes,
  Map<String, int> esperados,
) async {
  late Map<String, int> despues;
  bool completo() => esperados.entries.every(
    (e) => (despues[e.key] ?? 0) - (antes[e.key] ?? 0) >= e.value,
  );
  for (var intento = 0; intento < 20; intento++) {
    despues = await conteoEventos();
    if (completo()) break;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  for (final esperado in esperados.entries) {
    expect(
      (despues[esperado.key] ?? 0) - (antes[esperado.key] ?? 0),
      esperado.value,
      reason: 'evento ${esperado.key}',
    );
  }
}
