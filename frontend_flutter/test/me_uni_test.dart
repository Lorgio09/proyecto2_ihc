// Mis partidos > Me uní: loading errors, substitutes, leaving and the result.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/models/validacion.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/partidos_unidos_view.dart';

const _yo = Usuario(id: 2, nombre: 'Ana', email: 'ana@correo.com');
const _ana = UsuarioPartido(id: 2, nombre: 'Ana');

class _Servicio extends PartidoService {
  int cargas = 0;
  bool fallarCarga = false;
  Object? errorAlSalir;
  final llamadas = <String>[];

  final partido = Partido(
    id: 5,
    nombre: 'Fulbito',
    cantidadJugadores: 4,
    ubicacion: 'Cancha',
    fecha: DateTime.now().add(const Duration(days: 3)),
    estado: 'equipo completo',
    deporte: 'futbol',
    organizador: const UsuarioPartido(id: 1, nombre: 'Org'),
    suplentes: const [_ana],
    cantidadSuplentes: 1,
  );

  @override
  Future<List<Partido>> listarParticipando() async {
    cargas++;
    if (fallarCarga) throw Exception('sin red');
    return [partido];
  }

  @override
  Future<Partido> salir(int id) async {
    llamadas.add('salir $id');
    if (errorAlSalir != null) throw errorAlSalir!;
    return partido;
  }

  @override
  Future<void> registrarEvento(String evento, Map<String, Object?> props) async {}

  @override
  Future<Validacion> obtenerValidacion(int id) async => Validacion.fromJson({
    'partido_id': id,
    'nombre': 'Fulbito',
    'fecha': null,
    'ubicacion': 'Cancha',
    'organizador': {'id': 1, 'nombre': 'Org'},
    'equipos_aceptados': false,
    'partido_jugado': false,
    'estado_validacion': 'sin_equipos',
    'es_organizador': false,
    'es_capitan': false,
    'resultado_definitivo': null,
  });
}

Future<_Servicio> _abrir(WidgetTester tester, {bool fallar = false}) async {
  final servicio = _Servicio()..fallarCarga = fallar;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PartidosUnidosView(usuario: _yo, partidoService: servicio),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return servicio;
}

Future<void> _salirYConfirmar(WidgetTester tester) async {
  await tester.tap(find.text('Salir del partido'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('si no carga, lo dice y deja reintentar', (tester) async {
    final servicio = await _abrir(tester, fallar: true);
    expect(find.text('No se pudieron cargar tus partidos'), findsOneWidget);

    servicio.fallarCarga = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(servicio.cargas, 2);
    expect(find.widgetWithText(Card, 'Fulbito'), findsOneWidget);
  });

  testWidgets('quien es suplente lo ve en la tarjeta y puede salir', (tester) async {
    final servicio = await _abrir(tester);
    expect(find.text('Te uniste como suplente'), findsOneWidget);

    await _salirYConfirmar(tester);

    expect(servicio.llamadas, ['salir 5']);
    expect(find.text('Saliste del partido'), findsOneWidget);
  });

  testWidgets('si salir falla, muestra el error de la API', (tester) async {
    final servicio = await _abrir(tester);
    servicio.errorAlSalir = Exception('No se pudo salir del partido');

    await _salirYConfirmar(tester);

    expect(find.textContaining('No se pudo salir del partido'), findsOneWidget);
  });

  testWidgets('desde la tarjeta se abre el resultado del partido', (tester) async {
    await _abrir(tester);

    await tester.tap(find.byKey(const Key('boton-resultado-partido-5')));
    await tester.pumpAndSettle();

    expect(
      find.text('El organizador todavía no propuso los equipos'),
      findsOneWidget,
    );
  });
}
