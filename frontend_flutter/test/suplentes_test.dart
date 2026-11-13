import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/historial_partido.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

const _yo = Usuario(id: 7, nombre: 'Yo', email: 'yo@unisport.test');
const _ana = UsuarioPartido(id: 1, nombre: 'Ana');
const _beto = UsuarioPartido(id: 2, nombre: 'Beto');
const _carla = UsuarioPartido(id: 3, nombre: 'Carla');
const _yoComoParticipante = UsuarioPartido(id: 7, nombre: 'Yo');

Partido _partido({
  String estado = 'equipo completo',
  int cupos = 2,
  List<UsuarioPartido> titulares = const [_ana, _beto],
  List<UsuarioPartido> suplentes = const [],
}) {
  return Partido(
    id: 1,
    nombre: 'Duelo de dos',
    cantidadJugadores: cupos,
    ubicacion: 'Cancha central',
    fecha: DateTime.now().add(const Duration(days: 2)),
    estado: estado,
    organizador: const UsuarioPartido(id: 99, nombre: 'Org'),
    participantes: titulares,
    cantidadParticipantes: titulares.length,
    cuposDisponibles: (cupos - titulares.length).clamp(0, cupos),
    suplentes: suplentes,
    cantidadSuplentes: suplentes.length,
    deporte: 'futbol',
  );
}

class _Servicio extends PartidoService {
  _Servicio(this.partido, {this.alUnirse});

  Partido partido;
  Partido Function()? alUnirse;

  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async => [partido];

  @override
  Future<List<Partido>> listar() async => [partido];

  @override
  Future<Partido> unirse(int id) async {
    partido = alUnirse!();
    return partido;
  }
}

Future<void> _abrirExplorar(WidgetTester tester, _Servicio servicio) async {
  await tester.binding.setSurfaceSize(const Size(500, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ExplorarPartidosView(usuario: _yo, partidoService: servicio),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con el cupo lleno ofrece unirse como suplente', (tester) async {
    await _abrirExplorar(tester, _Servicio(_partido()));

    expect(find.text('Unirse como suplente'), findsOneWidget);
    expect(find.text('El equipo ya está completo'), findsNothing);
    expect(find.text('Cupos: 2/2'), findsOneWidget);
  });

  testWidgets('con lugares libres el botón sigue diciendo Unirse', (
    tester,
  ) async {
    await _abrirExplorar(
      tester,
      _Servicio(_partido(estado: 'cupos abiertos', cupos: 3)),
    );

    expect(find.text('Unirse'), findsOneWidget);
    expect(find.text('Unirse como suplente'), findsNothing);
  });

  testWidgets('equipo cerrado por el organizador con lugares libres rechaza', (
    tester,
  ) async {
    await _abrirExplorar(tester, _Servicio(_partido(cupos: 3)));

    expect(find.text('El equipo ya está completo'), findsOneWidget);
    expect(find.byKey(const Key('boton-unirse-partido')), findsNothing);
  });

  testWidgets('muestra cuántos suplentes esperan', (tester) async {
    await _abrirExplorar(
      tester,
      _Servicio(_partido(suplentes: const [_carla])),
    );

    expect(find.text('Suplentes: 1'), findsOneWidget);
  });

  testWidgets('quien es suplente lo ve y puede salir', (tester) async {
    await _abrirExplorar(
      tester,
      _Servicio(_partido(suplentes: const [_carla, _yoComoParticipante])),
    );

    expect(find.text('Eres suplente (posición 2)'), findsOneWidget);
    expect(find.byKey(const Key('boton-salir-partido')), findsOneWidget);
    expect(find.byKey(const Key('boton-unirse-partido')), findsNothing);
  });

  testWidgets('al unirse como suplente avisa que quedó en espera', (
    tester,
  ) async {
    final servicio = _Servicio(
      _partido(),
      alUnirse: () => _partido(suplentes: const [_yoComoParticipante]),
    );
    await _abrirExplorar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-unirse-partido')));
    await tester.pumpAndSettle();

    expect(find.text('Te uniste como suplente'), findsOneWidget);
    expect(find.text('Eres suplente (posición 1)'), findsOneWidget);
  });

  testWidgets('al unirse con lugar libre sigue avisando Te uniste al partido', (
    tester,
  ) async {
    final servicio = _Servicio(
      _partido(estado: 'cupos abiertos', cupos: 3),
      alUnirse: () => _partido(
        estado: 'cupos abiertos',
        cupos: 3,
        titulares: const [_ana, _beto, _yoComoParticipante],
      ),
    );
    await _abrirExplorar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-unirse-partido')));
    await tester.pumpAndSettle();

    expect(find.text('Te uniste al partido'), findsOneWidget);
  });

  testWidgets('el organizador ve a los suplentes aparte de los titulares', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ListPartidoView(
          partidoService: _Servicio(_partido(suplentes: const [_carla])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver participantes'));
    await tester.pumpAndSettle();

    expect(find.text('Ana, Beto'), findsOneWidget);
    expect(find.text('Suplentes: Carla'), findsOneWidget);
  });

  test('el historial traduce los eventos de suplentes', () {
    HistorialPartido evento(String accion) => HistorialPartido(
      id: 1,
      accion: accion,
      fechaEvento: DateTime(2026, 11, 1),
      partidoId: 1,
      nombrePartido: 'Duelo de dos',
      deporte: 'futbol',
      ubicacion: 'Cancha central',
      fechaPartido: null,
      estado: 'equipo completo',
    );

    expect(evento('se_unio').accionTexto, 'Te uniste al partido');
    expect(evento('se_unio_suplente').accionTexto, 'Te uniste como suplente');
    expect(evento('paso_a_titular').accionTexto, 'Pasaste a titular');
  });
}
