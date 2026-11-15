import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/services/cuenta_service.dart';
import 'package:frontend_flutter/views/cuenta/mi_cuenta_view.dart';

class _Servicio extends CuentaService {
  _Servicio({this.bloqueos = const []});

  final List<Map<String, dynamic>> bloqueos;
  final eventos = <String>[];
  final fallos = <Map<String, Object>>[];
  final guardados = <String, String>{};
  bool eliminada = false;

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
  Future<Map<String, dynamic>> antesDeEliminar() async => {
    'puede_eliminar': bloqueos.isEmpty,
    'bloqueos': bloqueos,
    'consecuencias': {
      'partidos_futuros': 2,
      'ascensos_de_suplentes': 1,
      'partidos_organizados_eliminados': 0,
      'resultados_anonimizados': 1,
    },
  };

  @override
  Future<void> eliminarCuenta() async => eliminada = true;

  @override
  Future<void> registrarEvento(
    String evento, {
    Map<String, Object> props = const {},
  }) async {
    eventos.add(evento);
    if (evento == 'tarea_fallida') fallos.add(props);
  }
}

Future<void> _abrir(WidgetTester tester, _Servicio servicio) async {
  // A phone-like screen tall enough for both sections.
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MiCuentaView(
        cuentaService: servicio,
        alSalir: (context) => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Login')),
          ),
          (_) => false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocarEliminar(WidgetTester tester) async {
  final boton = find.byKey(const Key('boton-eliminar-cuenta'));
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Mi cuenta muestra los datos y los descarga en JSON', (
    tester,
  ) async {
    final servicio = _Servicio();
    await _abrir(tester, servicio);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@correo.com'), findsOneWidget);
    expect(find.text('Partidos que organizas: 1'), findsOneWidget);
    expect(find.text('Partidos en los que participas: 2'), findsOneWidget);
    expect(servicio.eventos, ['mis_datos_vistos']);

    await tester.tap(find.byKey(const Key('boton-descargar-datos')));
    await tester.pumpAndSettle();

    // One file per download, named with the date and time.
    expect(servicio.guardados, hasLength(1));
    final nombre = servicio.guardados.keys.single;
    expect(nombre, matches(RegExp(r'^unisport-mis-datos-\d{8}-\d{6}\.json$')));
    final archivo = servicio.guardados[nombre]!;
    expect(jsonDecode(archivo)['cuenta']['email'], 'ana@correo.com');
    expect(servicio.eventos, ['mis_datos_vistos', 'mis_datos_descargados']);
    expect(
      find.text('Tus datos se guardaron en Descargas/$nombre'),
      findsOneWidget,
    );
  });

  testWidgets('La confirmación explica las consecuencias con botones iguales', (
    tester,
  ) async {
    final servicio = _Servicio();
    await _abrir(tester, servicio);
    await _tocarEliminar(tester);

    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(
      find.text(
        'Sales de 2 partidos que aún no se juegan. '
        'Tu lugar de titular pasa al primer suplente.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('aparecerás como "Usuario eliminado"'),
      findsOneWidget,
    );
    final cancelar = tester.getSize(
      find.byKey(const Key('cancelar-eliminar-cuenta')),
    );
    final confirmar = tester.getSize(
      find.byKey(const Key('confirmar-eliminar-cuenta')),
    );
    expect(cancelar, confirmar);

    // Cancel keeps everything as it was.
    await tester.tap(find.byKey(const Key('cancelar-eliminar-cuenta')));
    await tester.pumpAndSettle();
    expect(servicio.eliminada, isFalse);
    expect(find.text('Mi cuenta'), findsOneWidget);

    await _tocarEliminar(tester);
    await tester.tap(find.byKey(const Key('confirmar-eliminar-cuenta')));
    await tester.pumpAndSettle();

    expect(servicio.eliminada, isTrue);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Tu cuenta fue eliminada'), findsOneWidget);
    expect(
      servicio.eventos.where((e) => e == 'eliminacion_iniciada'),
      hasLength(2),
    );
  });

  testWidgets('Si la regla lo bloquea, dice por qué y qué hacer', (
    tester,
  ) async {
    final servicio = _Servicio(
      bloqueos: [
        {
          'codigo': 'ORGANIZA_PARTIDOS_CON_JUGADORES',
          'mensaje':
              'Organizas partidos que ya tienen jugadores: Fulbito. '
              'Elimínalos desde Mis partidos y vuelve a intentarlo.',
        },
      ],
    );
    await _abrir(tester, servicio);
    await _tocarEliminar(tester);

    expect(find.text('Todavía no puedes eliminar tu cuenta'), findsOneWidget);
    expect(find.textContaining('Fulbito'), findsOneWidget);
    expect(find.text('¿Eliminar tu cuenta?'), findsNothing);
    expect(servicio.fallos, [
      {'flujo': 'eliminar_cuenta', 'motivo': 'ORGANIZA_PARTIDOS_CON_JUGADORES'},
    ]);

    await tester.tap(find.byKey(const Key('cerrar-bloqueo')));
    await tester.pumpAndSettle();
    expect(servicio.eliminada, isFalse);
    expect(find.text('Mi cuenta'), findsOneWidget);
  });
}
