import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

const _yo = Usuario(id: 7, nombre: 'Yo', email: 'yo@unisport.test');
const _yoParticipante = UsuarioPartido(
  id: 7,
  nombre: 'Yo',
  email: 'yo@unisport.test',
);
const _ana = UsuarioPartido(id: 1, nombre: 'Ana', email: 'ana@test.com');

Partido _partido(int id, String nombre, List<UsuarioPartido> titulares) {
  return Partido(
    id: id,
    nombre: nombre,
    cantidadJugadores: 10,
    ubicacion: 'Cancha central',
    fecha: DateTime.now().add(const Duration(days: 2)),
    estado: 'cupos abiertos',
    organizador: const UsuarioPartido(
      id: 99,
      nombre: 'Org',
      email: 'org@test.com',
    ),
    participantes: titulares,
    cantidadParticipantes: titulares.length,
    cuposDisponibles: 10 - titulares.length,
    deporte: 'futbol',
  );
}

class _Servicio extends PartidoService {
  final propios = [_partido(1, 'Partido que organizo', const [])];
  var explorar = [
    _partido(2, 'Partido al que me uní', const [_ana, _yoParticipante]),
    _partido(3, 'Partido ajeno', const [_ana]),
  ];
  final salidos = <int>[];

  @override
  Future<List<Partido>> listar() async => propios;

  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async => explorar;

  @override
  Future<Partido> salir(int id) async {
    salidos.add(id);
    explorar = explorar.where((partido) => partido.id != id).toList();
    return _partido(id, 'x', const []);
  }
}

void main() {
  testWidgets('Mis partidos separa Organizo y Me uní', (tester) async {
    final servicio = _Servicio();
    await tester.pumpWidget(
      MaterialApp(
        home: ListPartidoView(partidoService: servicio, usuario: _yo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Organizo'), findsOneWidget);
    expect(find.text('Me uní'), findsOneWidget);
    expect(find.text('Partido que organizo'), findsOneWidget);

    await tester.tap(find.text('Me uní'));
    await tester.pumpAndSettle();

    expect(find.text('Partido al que me uní'), findsOneWidget);
    expect(find.text('Partido ajeno'), findsNothing);
    expect(find.byTooltip('Nuevo partido'), findsNothing);
  });

  testWidgets('Desde Me uní se puede salir del partido', (tester) async {
    final servicio = _Servicio();
    await tester.pumpWidget(
      MaterialApp(
        home: ListPartidoView(partidoService: servicio, usuario: _yo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me uní'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton-salir-partido-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
    await tester.pumpAndSettle();

    expect(servicio.salidos, [2]);
    expect(find.text('Partido al que me uní'), findsNothing);
    expect(find.text('Saliste del partido'), findsOneWidget);
    expect(find.text('Todavía no te uniste a ningún partido'), findsOneWidget);
  });

  testWidgets('Sin usuario se mantiene la vista anterior', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ListPartidoView(partidoService: _Servicio())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Me uní'), findsNothing);
    expect(find.text('Partido que organizo'), findsOneWidget);
    expect(find.byTooltip('Nuevo partido'), findsOneWidget);
  });
}
