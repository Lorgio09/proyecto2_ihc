// Explorar: un jugador cuyo partido fue reprogramado, y los filtros.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';

const _yo = Usuario(id: 2, nombre: 'Ana', email: 'ana@correo.com');
const _ana = UsuarioPartido(id: 2, nombre: 'Ana');
const _beto = UsuarioPartido(id: 3, nombre: 'Beto');

class _Servicio extends PartidoService {
  final busquedas = <Map<String, Object?>>[];
  final llamadas = <String>[];
  Object? errorAlReconfirmar;

  Partido partido = Partido(
    id: 7,
    nombre: 'Fulbito del jueves',
    cantidadJugadores: 2,
    ubicacion: 'Cancha central',
    fecha: DateTime.now().add(const Duration(days: 2)),
    estado: 'equipo completo',
    deporte: 'futbol',
    organizador: const UsuarioPartido(id: 1, nombre: 'Org'),
    participantes: const [_ana],
    cantidadParticipantes: 1,
    suplentes: const [_beto],
    cantidadSuplentes: 1,
    motivoReprogramacion: 'Lluvia',
    pendientesConfirmar: const [_ana],
  );

  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async {
    busquedas.add({'zona': zona, 'deporte': deporte, 'soloConCupos': soloConCupos});
    return [partido];
  }

  @override
  Future<Partido> reconfirmar(int id) async {
    llamadas.add('reconfirmar $id');
    if (errorAlReconfirmar != null) throw errorAlReconfirmar!;
    return partido;
  }

  @override
  Future<void> registrarEvento(String evento, Map<String, Object?> props) async {}
}

Future<_Servicio> _abrir(WidgetTester tester) async {
  final servicio = _Servicio();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ExplorarPartidosView(usuario: _yo, partidoService: servicio),
    ),
  );
  await tester.pumpAndSettle();
  return servicio;
}

void main() {
  testWidgets('si el partido cambió, pregunta si sigue jugando y lo confirma', (
    tester,
  ) async {
    final servicio = await _abrir(tester);

    expect(find.text('Reprogramado: Lluvia'), findsOneWidget);
    expect(find.text('El partido cambió. ¿Sigues jugando?'), findsOneWidget);
    expect(find.text('Suplentes: 1'), findsOneWidget);
    expect(find.text('Me retiro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton-reconfirmar-partido')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['reconfirmar 7']);
    expect(find.text('Confirmaste tu lugar en el partido'), findsOneWidget);
  });

  testWidgets('si reconfirmar falla, muestra el error de la API', (tester) async {
    final servicio = await _abrir(tester);
    servicio.errorAlReconfirmar = Exception('No se pudo confirmar tu lugar');

    await tester.tap(find.byKey(const Key('boton-reconfirmar-partido')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo confirmar tu lugar'), findsOneWidget);
  });

  testWidgets('el suplente ve su posición en la fila', (tester) async {
    final servicio = _Servicio();
    servicio.partido = Partido(
      id: 8,
      nombre: 'Duelo',
      cantidadJugadores: 1,
      ubicacion: 'Coliseo',
      fecha: DateTime.now().add(const Duration(days: 2)),
      estado: 'equipo completo',
      deporte: 'basquet',
      participantes: const [_beto],
      cantidadParticipantes: 1,
      suplentes: const [_ana],
      cantidadSuplentes: 1,
    );
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ExplorarPartidosView(usuario: _yo, partidoService: servicio),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eres suplente (posición 1)'), findsOneWidget);
  });

  testWidgets('zona, deporte y "Con cupos" vuelven a buscar con ese filtro', (
    tester,
  ) async {
    final servicio = await _abrir(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Zona o lugar'),
      'Norte',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(servicio.busquedas.last['zona'], 'Norte');

    await tester.tap(find.text('Todos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vóley').last);
    await tester.pumpAndSettle();
    expect(servicio.busquedas.last['deporte'], 'voley');

    // El chip está al final de una fila que se desplaza de lado.
    await tester.ensureVisible(find.text('Con cupos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Con cupos'));
    await tester.pumpAndSettle();
    expect(servicio.busquedas.last['soloConCupos'], isTrue);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar por nombre'),
      'Fulbito',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final cantidad = servicio.busquedas.length;
    await tester.tap(find.byTooltip('Buscar partidos'));
    await tester.pumpAndSettle();
    expect(servicio.busquedas.length, cantidad + 1);
  });

  testWidgets('"Me retiro" pide confirmación y se puede cancelar', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Me retiro'));
    await tester.pumpAndSettle();
    expect(find.text('Salir de Fulbito del jueves'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancelar-confirmacion')));
    await tester.pumpAndSettle();

    expect(find.text('Salir de Fulbito del jueves'), findsNothing);
  });
}
