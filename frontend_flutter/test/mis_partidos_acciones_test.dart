// Mis partidos (Organizo): the actions of a card and the notices it shows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/validacion.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

const _ana = UsuarioPartido(id: 2, nombre: 'Ana');
const _beto = UsuarioPartido(id: 3, nombre: 'Beto');

class _Servicio extends PartidoService {
  _Servicio(this.partidos);

  List<Partido> partidos;
  final eventos = <String>[];
  final fallos = <Map<String, Object?>>[];
  final llamadas = <String>[];
  Object? errorAlEliminar;

  @override
  Future<List<Partido>> listar() async => partidos;

  @override
  Future<void> registrarEvento(String evento, Map<String, Object?> props) async {
    eventos.add(evento);
    if (evento == 'tarea_fallida') fallos.add(props);
  }

  @override
  Future<void> eliminar(int id) async {
    llamadas.add('eliminar $id');
    if (errorAlEliminar != null) throw errorAlEliminar!;
  }

  @override
  Future<Partido> reabrir(int id) async {
    llamadas.add('reabrir $id');
    return partidos.first;
  }

  @override
  Future<Partido> reprogramar(
    int id, {
    DateTime? fecha,
    String? ubicacion,
    required String motivo,
  }) async {
    llamadas.add('reprogramar $id $ubicacion $motivo');
    return partidos.first;
  }

  @override
  Future<Validacion> obtenerValidacion(int id) async => Validacion.fromJson({
    'partido_id': id,
    'nombre': 'Fulbito',
    'fecha': null,
    'ubicacion': 'Cancha',
    'organizador': {'id': 1, 'nombre': 'Org'},
    'titulares': [],
    'equipo_a': [],
    'equipo_b': [],
    'capitan_rival': null,
    'equipos_aceptados': false,
    'partido_jugado': false,
    'estado_validacion': 'sin_equipos',
    'es_organizador': true,
    'es_capitan': false,
    'resultado_definitivo': null,
    'resultados': [],
  });
}

Partido _partido({
  int id = 1,
  String estado = 'equipo completo',
  String? motivo,
  List<UsuarioPartido> pendientes = const [],
  List<UsuarioPartido> bajas = const [],
  List<UsuarioPartido> participantes = const [],
}) => Partido(
  id: id,
  nombre: 'Fulbito $id',
  cantidadJugadores: 4,
  ubicacion: 'Cancha central',
  fecha: null,
  estado: estado,
  deporte: 'futbol',
  participantes: participantes,
  cantidadParticipantes: participantes.length,
  motivoReprogramacion: motivo,
  pendientesConfirmar: pendientes,
  bajasTardias: bajas,
);

Future<_Servicio> _abrir(WidgetTester tester, List<Partido> partidos) async {
  final servicio = _Servicio(partidos);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: ListPartidoView(partidoService: servicio)),
  );
  await tester.pumpAndSettle();
  return servicio;
}

Future<void> _menu(WidgetTester tester, String opcion) async {
  await tester.tap(find.byTooltip('Más acciones').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la tarjeta avisa reprogramación, respuestas pendientes y bajas tardías', (
    tester,
  ) async {
    await _abrir(tester, [
      _partido(motivo: 'Lluvia', pendientes: [_ana], bajas: [_beto]),
    ]);

    expect(find.text('Reprogramado: Lluvia'), findsOneWidget);
    expect(find.text('Esperando respuesta de: Ana'), findsOneWidget);
    expect(find.text('Bajas tardías: Beto'), findsOneWidget);
  });

  testWidgets('no deja reprogramar otra vez mientras faltan respuestas', (
    tester,
  ) async {
    final servicio = await _abrir(tester, [_partido(pendientes: [_ana])]);

    await _menu(tester, 'Reprogramar');

    expect(
      find.text(
        'Espera a que todos los titulares respondan antes de reprogramar otra vez',
      ),
      findsOneWidget,
    );
    expect(servicio.fallos.single, {
      'flujo': 'reprogramar',
      'motivo': 'REPROGRAMACION_PENDIENTE',
    });
  });

  testWidgets('reprograma el lugar con un motivo y avisa a los titulares', (
    tester,
  ) async {
    final servicio = await _abrir(tester, [_partido()]);

    await _menu(tester, 'Reprogramar');
    expect(servicio.eventos, contains('reprogramacion_iniciada'));
    await tester.enterText(
      find.byKey(const Key('campo-ubicacion-reprogramacion')),
      'Cancha norte',
    );
    await tester.enterText(
      find.byKey(const Key('campo-motivo-reprogramacion')),
      'Mantenimiento',
    );
    await tester.tap(find.byKey(const Key('confirmar-reprogramar-partido')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['reprogramar 1 Cancha norte Mantenimiento']);
    expect(find.text('Partido reprogramado. Avisamos a los titulares'), findsOneWidget);
  });

  testWidgets('cancelar la reprogramación no llama a la API', (tester) async {
    final servicio = await _abrir(tester, [_partido()]);

    await _menu(tester, 'Reprogramar');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, isEmpty);
  });

  testWidgets('reabre el equipo después de confirmar', (tester) async {
    final servicio = await _abrir(tester, [_partido()]);

    await tester.tap(find.byKey(const Key('boton-reabrir-partido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-reabrir-partido')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['reabrir 1']);
    expect(find.text('Equipo reabierto'), findsOneWidget);
  });

  testWidgets('al eliminar avisa a cuántos jugadores afecta y muestra el error de la API', (
    tester,
  ) async {
    final servicio = await _abrir(tester, [
      _partido(participantes: [_ana, _beto]),
    ]);
    servicio.errorAlEliminar = Exception('No se pudo eliminar');

    await _menu(tester, 'Eliminar partido');
    expect(
      find.text('Los 2 jugadores unidos dejan de verlo en Mis partidos.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirmar-eliminar-partido')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['eliminar 1']);
    expect(find.textContaining('No se pudo eliminar'), findsOneWidget);
  });

  testWidgets('con un solo jugador lo dice en singular', (tester) async {
    await _abrir(tester, [_partido(participantes: [_ana])]);

    await _menu(tester, 'Eliminar partido');

    expect(
      find.text('El jugador unido deja de verlo en Mis partidos.'),
      findsOneWidget,
    );
  });

  testWidgets('editar abre el formulario con el partido y se puede cancelar', (
    tester,
  ) async {
    final servicio = await _abrir(tester, [_partido()]);

    await _menu(tester, 'Editar partido');
    expect(find.text('Editar partido'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Editing is not part of the "create a match" funnel.
    expect(servicio.eventos, isNot(contains('partido_creacion_iniciada')));
  });

  testWidgets('abre la pantalla del resultado del partido', (tester) async {
    await _abrir(tester, [_partido()]);

    await _menu(tester, 'Resultado del partido');

    expect(
      find.text('El organizador todavía no propuso los equipos'),
      findsOneWidget,
    );
  });

  testWidgets('buscar con Enter aplica el filtro', (tester) async {
    await _abrir(tester, [_partido(id: 1), _partido(id: 2)]);

    await tester.enterText(find.byType(TextField).first, 'Fulbito 2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The search box also shows the typed text: look only inside the cards.
    expect(find.widgetWithText(Card, 'Fulbito 2'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Fulbito 1'), findsNothing);
  });
}
