// Resultado del partido: loading errors, accepting teams and the checks made
// before calling the API.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/validacion.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/resultado_partido_view.dart';

const _org = UsuarioPartido(id: 1, nombre: 'Org');
const _ana = UsuarioPartido(id: 2, nombre: 'Ana');
const _beto = UsuarioPartido(id: 3, nombre: 'Beto');

Validacion _validacion({
  required String estado,
  bool esOrganizador = false,
  bool esCapitan = false,
  bool jugado = false,
  List<VersionResultado> resultados = const [],
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
    equiposAceptados: estado == 'equipos_aceptados',
    partidoJugado: jugado,
    estado: estado,
    esOrganizador: esOrganizador,
    esCapitan: esCapitan,
    resultados: resultados,
  );
}

class _Servicio extends PartidoService {
  _Servicio(this.actual);

  Validacion actual;
  int cargas = 0;
  bool fallarCarga = false;
  Object? errorAlAceptar;
  final llamadas = <String>[];

  @override
  Future<Validacion> obtenerValidacion(int id) async {
    cargas++;
    if (fallarCarga) throw Exception('No se pudo cargar el resultado');
    return actual;
  }

  @override
  Future<Validacion> aceptarEquipos(int id) async {
    llamadas.add('aceptar');
    if (errorAlAceptar != null) throw errorAlAceptar!;
    return actual = _validacion(estado: 'equipos_aceptados', esCapitan: true);
  }

  @override
  Future<Validacion> proponerEquipos(
    int id, {
    required List<int> equipoB,
    required int capitanId,
  }) async {
    llamadas.add('proponer');
    return actual;
  }

  @override
  Future<Validacion> registrarResultado(int id, int golesA, int golesB) async {
    llamadas.add('registrar');
    return actual;
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
  testWidgets('si no carga, muestra el error y deja reintentar', (tester) async {
    final servicio = _Servicio(_validacion(estado: 'sin_equipos'))
      ..fallarCarga = true;
    await _mostrar(tester, servicio);
    expect(find.textContaining('No se pudo cargar el resultado'), findsOneWidget);

    servicio.fallarCarga = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(servicio.cargas, 2);
    expect(find.byKey(const Key('estado-validacion')), findsOneWidget);
  });

  testWidgets('el capitán acepta los equipos que le propusieron', (tester) async {
    final servicio = _Servicio(
      _validacion(estado: 'equipos_propuestos', esCapitan: true),
    );
    await _mostrar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-aceptar-equipos')));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['aceptar']);
    expect(find.text('Aceptaste los equipos'), findsOneWidget);
  });

  testWidgets('si la API rechaza la acción, se ve su mensaje', (tester) async {
    final servicio = _Servicio(
      _validacion(estado: 'equipos_propuestos', esCapitan: true),
    )..errorAlAceptar = Exception('Solo el capitán acepta los equipos');
    await _mostrar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-aceptar-equipos')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Solo el capitán acepta los equipos'),
      findsOneWidget,
    );
  });

  testWidgets('desmarcar al capitán lo quita y sin capitán no se proponen equipos', (
    tester,
  ) async {
    final servicio = _Servicio(
      _validacion(estado: 'sin_equipos', esOrganizador: true),
    );
    await _mostrar(tester, servicio);

    await tester.tap(find.byKey(const Key('equipo-b-Beto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capitan-Beto')));
    await tester.pumpAndSettle();
    // Unticking the captain from team B also clears the captain.
    await tester.tap(find.byKey(const Key('equipo-b-Beto')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capitan-Beto')), findsNothing);

    await tester.tap(find.byKey(const Key('boton-proponer-equipos')));
    await tester.pumpAndSettle();

    expect(
      find.text('Elige el equipo rival y un capitán que sea parte de él'),
      findsOneWidget,
    );
    expect(servicio.llamadas, isEmpty);
  });

  testWidgets('sin goles escritos no registra el marcador', (tester) async {
    final servicio = _Servicio(
      _validacion(estado: 'equipos_aceptados', esOrganizador: true, jugado: true),
    );
    await _mostrar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-registrar-marcador')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe los goles de los dos equipos'), findsOneWidget);
    expect(servicio.llamadas, isEmpty);
  });

  testWidgets('la ayuda explica cómo se valida el resultado', (tester) async {
    await _mostrar(tester, _Servicio(_validacion(estado: 'sin_equipos')));

    await tester.tap(find.byTooltip('Ayuda'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('cancelar la disputa la cierra sin enviar nada', (tester) async {
    final servicio = _Servicio(
      _validacion(
        estado: 'resultado_pendiente',
        esCapitan: true,
        jugado: true,
        resultados: [
          VersionResultado(
            version: 1,
            golesA: 2,
            golesB: 1,
            estado: 'pendiente',
            registradoEn: DateTime(2026, 11, 10, 18),
          ),
        ],
      ),
    );
    await _mostrar(tester, servicio);

    await tester.tap(find.byKey(const Key('boton-disputar-resultado')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campo-motivo-disputa')), findsNothing);
    expect(servicio.llamadas, isEmpty);
  });
}
