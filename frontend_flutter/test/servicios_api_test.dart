// The services that talk to the API, with the HTTP answers simulated: what
// each call sends, how the answer is read and how an error reaches the screen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/historial_partido.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/validacion.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/cuenta_service.dart';
import 'package:frontend_flutter/services/descarga_io.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements TokenStorage {
  String? valor = 'token-de-prueba';

  @override
  Future<String?> read() async => valor;

  @override
  Future<void> write(String token) async => valor = token;

  @override
  Future<void> delete() async => valor = null;
}

Map<String, dynamic> _partido({int id = 1}) => {
  'id': id,
  'nombre': 'Fulbito',
  'cantidad_jugadores': 10,
  'ubicacion': 'Cancha central',
  'tiempo_min': '60',
  'fecha': '2026-11-20T22:00:00Z',
  'estado': 'cupos abiertos',
  'organizador': {'id': 9, 'nombre': 'Org'},
  'participantes': [],
  'deporte': 'futbol',
};

Map<String, dynamic> _validacion() => {
  'partido_id': 1,
  'nombre': 'Clásico',
  'fecha': '2026-11-17T20:00:00Z',
  'ubicacion': 'Cancha',
  'organizador': {'id': 1, 'nombre': 'Org'},
  'titulares': [
    {'id': 2, 'nombre': 'Ana'},
    {'id': 3, 'nombre': 'Beto'},
  ],
  'equipo_a': [
    {'id': 2, 'nombre': 'Ana'},
  ],
  'equipo_b': [
    {'id': 3, 'nombre': 'Beto'},
  ],
  'capitan_rival': {'id': 3, 'nombre': 'Beto'},
  'equipos_aceptados': true,
  'partido_jugado': true,
  'estado_validacion': 'resultado_confirmado',
  'es_organizador': false,
  'es_capitan': true,
  'resultado_definitivo': {'goles_a': 2, 'goles_b': 1},
  'resultados': [
    {
      'version': 1,
      'goles_a': 2,
      'goles_b': 1,
      'estado': 'confirmado',
      'motivo_disputa': null,
      'registrado_en': '2026-11-17T22:00:00Z',
    },
  ],
};

http.Response _json(Object cuerpo, [int estado = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(cuerpo)),
  estado,
  headers: {'content-type': 'application/json'},
);

http.Response _error(int estado, String codigo, String mensaje) =>
    _json({
      'detail': {'codigo': codigo, 'mensaje': mensaje},
    }, estado);

void main() {
  group('PartidoService', () {
    late List<http.Request> pedidos;
    late http.Response Function(http.Request) responder;
    late PartidoService servicio;

    setUp(() {
      pedidos = [];
      responder = (_) => _json(_partido());
      servicio = PartidoService(
        client: MockClient((pedido) async {
          pedidos.add(pedido);
          return responder(pedido);
        }),
        storage: _Token(),
      );
    });

    test('cada acción llama a su ruta con el token y lee el partido', () async {
      await servicio.reprogramar(
        1,
        fecha: DateTime.utc(2026, 11, 21, 20),
        ubicacion: 'Cancha norte',
        motivo: 'Lluvia',
      );
      await servicio.reconfirmar(1);
      await servicio.unirse(1);
      await servicio.salir(1);
      final reabierto = await servicio.reabrir(1);

      expect(reabierto.nombre, 'Fulbito');
      expect(pedidos.map((p) => '${p.method} ${p.url.path}'), [
        'PATCH /api/partidos/1/reprogramar',
        'POST /api/partidos/1/reconfirmar',
        'POST /api/partidos/1/unirse',
        'DELETE /api/partidos/1/salir',
        'PATCH /api/partidos/1/reabrir',
      ]);
      expect(
        pedidos.first.headers['Authorization'],
        'Bearer token-de-prueba',
      );
      expect(jsonDecode(pedidos.first.body), {
        'fecha': '2026-11-21T20:00:00.000Z',
        'ubicacion': 'Cancha norte',
        'motivo': 'Lluvia',
      });
    });

    test('un error de la API llega con su código y su mensaje', () async {
      responder = (_) => _error(409, 'EQUIPO_COMPLETO', 'El equipo ya está completo');
      final acciones = <Future<Object?> Function()>[
        () => servicio.reprogramar(1, motivo: 'x'),
        () => servicio.reconfirmar(1),
        () => servicio.unirse(1),
        () => servicio.salir(1),
        () => servicio.reabrir(1),
        () => servicio.listarHistorial(),
        () => servicio.listarParticipando(),
        () => servicio.obtenerValidacion(1),
      ];
      for (final accion in acciones) {
        await expectLater(
          accion(),
          throwsA(
            isA<PartidoError>()
                .having((e) => e.codigo, 'codigo', 'EQUIPO_COMPLETO')
                .having((e) => '$e', 'texto', 'El equipo ya está completo'),
          ),
        );
      }
    });

    test('historial y partidos en los que participa', () async {
      responder = (pedido) => pedido.url.path.endsWith('/historial')
          ? _json([
              {
                'id': 1,
                'accion': 'baja_tardia',
                'fecha_evento': '2026-11-17T20:00:00Z',
                'partido_id': 1,
                'nombre_partido': 'Fulbito',
                'deporte': 'futbol',
                'ubicacion': 'Cancha',
                'fecha_partido': null,
                'estado': 'cupos abiertos',
              },
            ])
          : _json([_partido(id: 1), _partido(id: 2)]);

      final historial = await servicio.listarHistorial();
      expect(historial.single, isA<HistorialPartido>());
      expect(historial.single.accionTexto, 'Te diste de baja tarde');
      expect((await servicio.listarParticipando()).map((p) => p.id), [1, 2]);
    });

    test('validación: cada paso envía lo suyo y lee equipos y marcador', () async {
      responder = (_) => _json(_validacion());

      await servicio.proponerEquipos(1, equipoB: [3], capitanId: 3);
      await servicio.aceptarEquipos(1);
      await servicio.registrarResultado(1, 2, 1);
      await servicio.confirmarResultado(1);
      final datos = await servicio.disputarResultado(1, 'Gol anulado');

      expect(pedidos.map((p) => p.url.path), [
        '/api/partidos/1/equipos',
        '/api/partidos/1/equipos/aceptar',
        '/api/partidos/1/resultados',
        '/api/partidos/1/resultados/confirmar',
        '/api/partidos/1/resultados/disputar',
      ]);
      expect(jsonDecode(pedidos[0].body), {
        'equipo_b': [3],
        'capitan_rival_id': 3,
      });
      expect(jsonDecode(pedidos[2].body), {'goles_a': 2, 'goles_b': 1});
      expect(jsonDecode(pedidos[4].body), {'motivo': 'Gol anulado'});

      expect(datos.capitanRival?.nombre, 'Beto');
      expect(datos.equipoA.single.nombre, 'Ana');
      expect(datos.resultadoDefinitivo, (2, 1));
      expect(datos.resultados.single.estadoTexto, 'Confirmado');
      expect(datos.estadoTexto, 'Resultado confirmado');
    });

    test('un error sin formato conocido usa el mensaje de la pantalla', () async {
      responder = (_) => http.Response('<html>caído</html>', 500);
      await expectLater(
        servicio.unirse(1),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'texto',
            contains('No se pudo unir al partido'),
          ),
        ),
      );
    });

    test('la analítica nunca rompe la acción aunque la red falle', () async {
      final sinRed = PartidoService(
        client: MockClient((_) async => throw const SocketException('sin red')),
        storage: _Token(),
      );
      await sinRed.registrarEvento('union_iniciada', {'deporte': 'futbol'});
    });
  });

  group('Validacion', () {
    test('describe cada estado en palabras', () {
      String texto(String estado, {bool jugado = false}) => Validacion.fromJson({
        ..._validacion(),
        'estado_validacion': estado,
        'partido_jugado': jugado,
        'fecha': null,
        'capitan_rival': null,
        'resultado_definitivo': null,
      }).estadoTexto;

      expect(texto('sin_equipos'), contains('todavía no propuso'));
      expect(texto('equipos_propuestos'), contains('acepte los equipos'));
      expect(texto('equipos_aceptados'), contains('al terminar el partido'));
      expect(
        texto('equipos_aceptados', jugado: true),
        contains('Falta registrar'),
      );
      expect(texto('resultado_pendiente'), contains('validación'));
      expect(texto('resultado_disputado'), contains('disputado'));
      expect(texto('otro'), 'otro');

      String version(String estado) => VersionResultado.fromJson({
        ...(_validacion()['resultados'] as List).single as Map<String, dynamic>,
        'estado': estado,
      }).estadoTexto;
      expect(version('pendiente'), 'Esperando validación');
      expect(version('disputado'), 'Disputado');
      expect(version('raro'), 'raro');
    });
  });

  group('CuentaService', () {
    late List<http.Request> pedidos;
    late http.Response Function(http.Request) responder;
    late _Token token;
    late CuentaService servicio;

    setUp(() {
      pedidos = [];
      token = _Token();
      responder = (_) => _json({});
      servicio = CuentaService(
        client: MockClient((pedido) async {
          pedidos.add(pedido);
          return responder(pedido);
        }),
        storage: token,
      );
    });

    test('lee mis datos y lo que pasaría al eliminar la cuenta', () async {
      responder = (pedido) => pedido.url.path.endsWith('/mis-datos')
          ? _json({
              'cuenta': {'nombre': 'Ñandú', 'email': 'a@b.c'},
            })
          : _json({'puede_eliminar': true, 'bloqueos': []});

      expect((await servicio.misDatos())['cuenta']['nombre'], 'Ñandú');
      expect((await servicio.antesDeEliminar())['puede_eliminar'], isTrue);
      expect(pedidos.map((p) => p.url.path), [
        '/api/cuenta/mis-datos',
        '/api/cuenta/eliminacion',
      ]);
    });

    test('si la API falla, avisa con un mensaje claro', () async {
      responder = (_) => http.Response('', 500);
      await expectLater(
        servicio.misDatos(),
        throwsA(
          isA<Exception>().having((e) => '$e', 't', contains('tus datos')),
        ),
      );
      await expectLater(
        servicio.antesDeEliminar(),
        throwsA(
          isA<Exception>().having((e) => '$e', 't', contains('revisar tu cuenta')),
        ),
      );
      await expectLater(
        servicio.eliminarCuenta(),
        throwsA(
          isA<Exception>().having((e) => '$e', 't', contains('eliminar la cuenta')),
        ),
      );
    });

    test('al eliminar la cuenta se borra la sesión guardada', () async {
      responder = (_) => http.Response('', 204);
      await servicio.eliminarCuenta();
      expect(pedidos.single.method, 'DELETE');
      expect(token.valor, isNull);
    });

    test('un bloqueo llega con por qué y qué hacer', () async {
      responder = (_) => _json({
        'detail': {
          'codigo': 'ORGANIZA_PARTIDOS_CON_JUGADORES',
          'mensaje': 'Organizas partidos con jugadores.',
          'bloqueos': [
            {
              'codigo': 'ORGANIZA_PARTIDOS_CON_JUGADORES',
              'mensaje': 'Organizas partidos con jugadores.',
            },
          ],
        },
      }, 409);
      await expectLater(
        servicio.eliminarCuenta(),
        throwsA(
          isA<CuentaBloqueada>().having(
            (e) => e.bloqueos.single['codigo'],
            'codigo',
            'ORGANIZA_PARTIDOS_CON_JUGADORES',
          ),
        ),
      );
      expect(token.valor, 'token-de-prueba');
    });

    test('registra eventos con sus propiedades y no falla sin red', () async {
      await servicio.registrarEvento(
        'tarea_fallida',
        props: {'flujo': 'eliminar_cuenta', 'motivo': 'X'},
      );
      expect(jsonDecode(pedidos.single.body), {
        'evento': 'tarea_fallida',
        'props': {'flujo': 'eliminar_cuenta', 'motivo': 'X'},
      });

      final sinRed = CuentaService(
        client: MockClient((_) async => throw const SocketException('sin red')),
        storage: token,
      );
      await sinRed.registrarEvento('mis_datos_vistos');
    });
  });

  test('la descarga queda en la carpeta Descargas de la persona', () async {
    final inicio =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final nombre =
        'unisport-prueba-${DateTime.now().microsecondsSinceEpoch}.json';
    final ruta = await guardarArchivo(nombre, '{"ok": true}');
    addTearDown(() => File(ruta).deleteSync());

    expect(ruta, startsWith(inicio!));
    expect(ruta, contains('Downloads'));
    expect(await File(ruta).readAsString(), '{"ok": true}');
  });

  test('la carpeta de descargas según el dispositivo', () {
    expect(
      carpetaDescargas(android: true).path,
      '/storage/emulated/0/Download',
    );
    expect(
      carpetaDescargas(android: false, entorno: {'HOME': '/home/ana'}).path,
      '/home/ana${Platform.pathSeparator}Downloads',
    );
    expect(
      carpetaDescargas(android: false, entorno: {'USERPROFILE': r'C:\Ana'}).path,
      'C:\\Ana${Platform.pathSeparator}Downloads',
    );
    // With no home folder at all, the system's temporary folder.
    expect(
      carpetaDescargas(android: false, entorno: {}).path,
      Directory.systemTemp.path,
    );
  });

  test('Mi cuenta guarda el archivo con el servicio de descargas', () async {
    final nombre = 'unisport-cuenta-${DateTime.now().microsecondsSinceEpoch}.json';
    final ruta = await CuentaService(storage: _Token()).guardarEnDescargas(
      nombre,
      '{}',
    );
    addTearDown(() => File(ruta).deleteSync());
    expect(File(ruta).existsSync(), isTrue);
  });

  test('editar un partido solo envía lo que cambió', () {
    final cambios = PartidoUpdateRequest(
      tiempoMin: '90',
      deporte: 'voley',
    ).toJson();
    expect(cambios, {'tiempo_min': '90', 'deporte': 'voley'});
  });
}
