// Mi cuenta cuando algo sale mal, y la salida a la pantalla de inicio de
// sesión.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/services/cuenta_service.dart';
import 'package:frontend_flutter/views/cuenta/mi_cuenta_view.dart';

class _Servicio extends CuentaService {
  bool fallarCarga = false;
  int cargas = 0;
  Object? errorAlGuardar;
  Object? errorAlEliminar;
  int organizados = 0;
  final eventos = <String>[];

  @override
  Future<Map<String, dynamic>> misDatos() async {
    cargas++;
    if (fallarCarga) throw Exception('sin red');
    return {
      'cuenta': {'nombre': 'Ana', 'email': 'ana@correo.com', 'telefono': null},
      'partidos_organizados': [],
      'participaciones': [],
      'historial': [],
    };
  }

  @override
  Future<String> guardarEnDescargas(String nombre, String contenido) async {
    if (errorAlGuardar != null) throw errorAlGuardar!;
    return nombre;
  }

  @override
  Future<Map<String, dynamic>> antesDeEliminar() async => {
    'puede_eliminar': true,
    'bloqueos': [],
    'consecuencias': {
      'partidos_futuros': 0,
      'ascensos_de_suplentes': 0,
      'partidos_organizados_eliminados': organizados,
      'resultados_anonimizados': 0,
    },
  };

  @override
  Future<void> eliminarCuenta() async {
    if (errorAlEliminar != null) throw errorAlEliminar!;
  }

  @override
  Future<void> registrarEvento(
    String evento, {
    Map<String, Object> props = const {},
  }) async => eventos.add(evento);
}

Future<_Servicio> _abrir(WidgetTester tester, _Servicio servicio) async {
  // Un teléfono alto, para que ambas secciones quepan sin desplazarse.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: MiCuentaView(cuentaService: servicio)));
  await tester.pumpAndSettle();
  return servicio;
}

Future<void> _eliminarYConfirmar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('boton-eliminar-cuenta')));
  await tester.tap(find.byKey(const Key('boton-eliminar-cuenta')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirmar-eliminar-cuenta')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('si no carga los datos, lo dice y deja reintentar', (tester) async {
    final servicio = await _abrir(tester, _Servicio()..fallarCarga = true);
    expect(find.text('No se pudieron cargar tus datos'), findsOneWidget);

    servicio.fallarCarga = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(servicio.cargas, 2);
    expect(find.text('ana@correo.com'), findsOneWidget);
  });

  testWidgets('si no puede guardar el archivo, avisa', (tester) async {
    await _abrir(tester, _Servicio()..errorAlGuardar = Exception('disco lleno'));

    await tester.tap(find.byKey(const Key('boton-descargar-datos')));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el archivo'), findsOneWidget);
  });

  testWidgets('dice cuántos partidos propios se borran', (tester) async {
    await _abrir(tester, _Servicio()..organizados = 2);

    await tester.ensureVisible(find.byKey(const Key('boton-eliminar-cuenta')));
    await tester.tap(find.byKey(const Key('boton-eliminar-cuenta')));
    await tester.pumpAndSettle();

    expect(find.text('Se eliminan 2 partidos que organizas.'), findsOneWidget);
  });

  testWidgets('si al confirmar aparece un bloqueo, lo explica sin registrarlo otra vez', (
    tester,
  ) async {
    final servicio = await _abrir(
      tester,
      _Servicio()
        ..errorAlEliminar = CuentaBloqueada([
          {
            'codigo': 'CAPITAN_CON_RESULTADO_PENDIENTE',
            'mensaje': 'Hay un marcador esperando tu validación.',
          },
        ]),
    );

    await _eliminarYConfirmar(tester);

    expect(find.text('Todavía no puedes eliminar tu cuenta'), findsOneWidget);
    expect(find.text('Hay un marcador esperando tu validación.'), findsOneWidget);
    // El backend ya registró este bloqueo.
    expect(servicio.eventos, isNot(contains('tarea_fallida')));
  });

  testWidgets('si la API falla al eliminar, avisa y la cuenta sigue', (tester) async {
    await _abrir(tester, _Servicio()..errorAlEliminar = Exception('sin red'));

    await _eliminarYConfirmar(tester);

    expect(
      find.text('No se pudo eliminar la cuenta. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Mi cuenta'), findsOneWidget);
  });

  testWidgets('al eliminarla vuelve a la pantalla de inicio de sesión', (tester) async {
    await _abrir(tester, _Servicio());

    await _eliminarYConfirmar(tester);

    expect(find.byKey(const Key('boton-ingresar')), findsOneWidget);
    expect(find.text('Tu cuenta fue eliminada'), findsOneWidget);
  });
}
