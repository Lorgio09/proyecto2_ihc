import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/services/cuenta_service.dart';
import 'package:frontend_flutter/views/cuenta/mi_cuenta_view.dart';

class _Servicio extends CuentaService {
  final eventos = <String>[];
  final guardados = <String, String>{};

  @override
  Future<Map<String, dynamic>> misDatos() async => {
    'cuenta': {'nombre': 'Ana', 'email': 'ana@correo.com', 'telefono': null},
    'partidos_organizados': [
      {'nombre': 'Fulbito'},
    ],
    'participaciones': [
      {'partido': 'Basket'},
      {'partido': 'Voley'},
    ],
    'historial': [],
  };

  @override
  Future<String> guardarEnDescargas(String nombre, String contenido) async {
    guardados[nombre] = contenido;
    return '/Download/$nombre';
  }

  @override
  Future<void> registrarEvento(String evento) async => eventos.add(evento);
}

void main() {
  testWidgets('Mi cuenta muestra los datos y los descarga en JSON', (
    tester,
  ) async {
    final servicio = _Servicio();
    await tester.pumpWidget(
      MaterialApp(home: MiCuentaView(cuentaService: servicio)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@correo.com'), findsOneWidget);
    expect(find.text('Partidos que organizas: 1'), findsOneWidget);
    expect(find.text('Partidos en los que participas: 2'), findsOneWidget);
    expect(servicio.eventos, ['mis_datos_vistos']);

    await tester.tap(find.byKey(const Key('boton-descargar-datos')));
    await tester.pumpAndSettle();

    final archivo = servicio.guardados['unisport-mis-datos.json'];
    expect(archivo, isNotNull);
    expect(jsonDecode(archivo!)['cuenta']['email'], 'ana@correo.com');
    expect(servicio.eventos, ['mis_datos_vistos', 'mis_datos_descargados']);
    expect(
      find.text('Tus datos se guardaron en Descargas/unisport-mis-datos.json'),
      findsOneWidget,
    );
  });
}
