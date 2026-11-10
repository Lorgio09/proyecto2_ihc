import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/validacion.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/resultado_partido_view.dart';

const _org = UsuarioPartido(id: 1, nombre: 'Org', email: 'org@test.com');
const _ana = UsuarioPartido(id: 2, nombre: 'Ana', email: 'ana@test.com');
const _beto = UsuarioPartido(id: 3, nombre: 'Beto', email: 'beto@test.com');

Validacion _validacion({
  required String estado,
  bool esOrganizador = false,
  bool esCapitan = false,
  bool jugado = true,
  List<VersionResultado> resultados = const [],
  (int, int)? definitivo,
}) {
  final conEquipos = estado != 'sin_equipos';
  return Validacion(
    partidoId: 10,
    nombre: 'Clásico',
    ubicacion: 'Cancha FICCT',
    organizador: _org,
    titulares: const [_ana, _beto],
    equipoA: conEquipos ? const [_ana] : const [],
    equipoB: conEquipos ? const [_beto] : const [],
    capitanRival: conEquipos ? _beto : null,
    equiposAceptados: estado != 'equipos_propuestos' && conEquipos,
    partidoJugado: jugado,
    estado: estado,
    esOrganizador: esOrganizador,
    esCapitan: esCapitan,
    resultados: resultados,
    resultadoDefinitivo: definitivo,
  );
}

VersionResultado _version(
  int n,
  int a,
  int b,
  String estado, [
  String? motivo,
]) => VersionResultado(
  version: n,
  golesA: a,
  golesB: b,
  estado: estado,
  motivoDisputa: motivo,
  registradoEn: DateTime(2026, 11, 10, 18),
);

class _Servicio extends PartidoService {
  _Servicio(this.actual);

  Validacion actual;
  final llamadas = <String>[];

  @override
  Future<Validacion> obtenerValidacion(int id) async => actual;

  @override
  Future<Validacion> disputarResultado(int id, String motivo) async {
    llamadas.add('disputar:$motivo');
    return actual = _validacion(
      estado: 'resultado_disputado',
      esCapitan: true,
      resultados: [_version(1, 3, 2, 'disputado', motivo)],
    );
  }

  @override
  Future<Validacion> confirmarResultado(int id) async {
    llamadas.add('confirmar');
    return actual = _validacion(
      estado: 'resultado_confirmado',
      esCapitan: true,
      resultados: [_version(1, 3, 2, 'confirmado')],
      definitivo: (3, 2),
    );
  }

  @override
  Future<Validacion> registrarResultado(int id, int golesA, int golesB) async {
    llamadas.add('registrar:$golesA-$golesB');
    return actual = _validacion(
      estado: 'resultado_pendiente',
      esOrganizador: true,
      resultados: [
        _version(2, golesA, golesB, 'pendiente'),
        ...actual.resultados,
      ],
    );
  }

  @override
  Future<Validacion> proponerEquipos(
    int id, {
    required List<int> equipoB,
    required int capitanId,
  }) async {
    llamadas.add('proponer:$equipoB:$capitanId');
    return actual = _validacion(
      estado: 'equipos_propuestos',
      esOrganizador: true,
    );
  }
}

Future<void> _mostrar(WidgetTester tester, _Servicio servicio) async {
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ResultadoPartidoView(partidoId: 10, partidoService: servicio),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('El capitán disputa con motivo y el marcador no es definitivo', (
    tester,
  ) async {
    final servicio = _Servicio(
      _validacion(
        estado: 'resultado_pendiente',
        esCapitan: true,
        resultados: [_version(1, 3, 2, 'pendiente')],
      ),
    );
    await _mostrar(tester, servicio);

    expect(find.text('Todavía no hay un resultado definitivo'), findsOneWidget);
    expect(
      find.text('El organizador registró: Equipo A 3 - 2 Equipo B'),
      findsOneWidget,
    );

    // An empty reason is not sent.
    await tester.tap(find.byKey(const Key('boton-disputar-resultado')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-disputa')));
    await tester.pumpAndSettle();
    expect(servicio.llamadas, isEmpty);
    expect(find.text('Escribe el motivo de la disputa'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton-disputar-resultado')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-motivo-disputa')),
      'Gol en fuera de juego',
    );
    await tester.tap(find.byKey(const Key('enviar-disputa')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['disputar:Gol en fuera de juego']);
    expect(find.text('Versión 1: 3 - 2 · Disputado'), findsOneWidget);
    expect(find.text('Motivo: Gol en fuera de juego'), findsOneWidget);
    expect(find.text('Todavía no hay un resultado definitivo'), findsOneWidget);
    expect(find.byKey(const Key('boton-confirmar-resultado')), findsNothing);
  });

  testWidgets('El organizador corrige un marcador disputado', (tester) async {
    final servicio = _Servicio(
      _validacion(
        estado: 'resultado_disputado',
        esOrganizador: true,
        resultados: [_version(1, 3, 2, 'disputado', 'Gol anulado')],
      ),
    );
    await _mostrar(tester, servicio);

    expect(find.text('Corregir el marcador'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-goles-a')), '2');
    await tester.enterText(find.byKey(const Key('campo-goles-b')), '2');
    await tester.tap(find.text('Registrar corrección'));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['registrar:2-2']);
    expect(
      find.text('Versión 2: 2 - 2 · Esperando validación'),
      findsOneWidget,
    );
    expect(find.text('Versión 1: 3 - 2 · Disputado'), findsOneWidget);
    // The organizer cannot validate their own score.
    expect(find.byKey(const Key('boton-confirmar-resultado')), findsNothing);
  });

  testWidgets('Al confirmar, el marcador pasa a ser definitivo', (
    tester,
  ) async {
    final servicio = _Servicio(
      _validacion(
        estado: 'resultado_pendiente',
        esCapitan: true,
        resultados: [_version(1, 3, 2, 'pendiente')],
      ),
    );
    await _mostrar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-confirmar-resultado')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['confirmar']);
    expect(find.text('Equipo A 3 - 2 Equipo B'), findsOneWidget);
    expect(find.text('Resultado confirmado'), findsWidgets);
  });

  testWidgets('Un jugador que no es capitán solo puede ver', (tester) async {
    await _mostrar(
      tester,
      _Servicio(
        _validacion(
          estado: 'resultado_pendiente',
          resultados: [_version(1, 3, 2, 'pendiente')],
        ),
      ),
    );

    expect(find.byKey(const Key('boton-confirmar-resultado')), findsNothing);
    expect(find.byKey(const Key('boton-disputar-resultado')), findsNothing);
    expect(find.byKey(const Key('boton-registrar-marcador')), findsNothing);
    expect(
      find.text('Marcador esperando la validación del capitán'),
      findsOneWidget,
    );
  });

  testWidgets(
    'El organizador propone equipos con un capitán del equipo rival',
    (tester) async {
      final servicio = _Servicio(
        _validacion(estado: 'sin_equipos', esOrganizador: true, jugado: false),
      );
      await _mostrar(tester, servicio);

      // Without a rival team there is no captain to choose.
      expect(
        find.text('Primero marca al menos un jugador del equipo rival'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('equipo-b-Beto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capitan-Beto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boton-proponer-equipos')));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, ['proponer:[3]:3']);
      expect(
        find.text('Esperando que el capitán rival acepte los equipos'),
        findsOneWidget,
      );
    },
  );
}
