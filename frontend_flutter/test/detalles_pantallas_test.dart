// Comportamientos menores de las pantallas: la navegación desde el inicio, las
// validaciones del formulario de partido, los estados de carga y algunos
// detalles de tarjeta.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/home_view/home_view.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';
import 'package:frontend_flutter/views/partido_view/formulario_partido.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';
import 'package:frontend_flutter/widgets/input.dart';
import 'package:frontend_flutter/widgets/tarjeta_partido.dart';

const _yo = Usuario(id: 2, nombre: 'Ana', email: 'ana@correo.com');
const _ana = UsuarioPartido(id: 2, nombre: 'Ana');

void _telefono(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

class _Servicio extends PartidoService {
  _Servicio(this.partidos);

  List<Partido> partidos;
  final eventos = <String>[];
  final fallos = <String>[];
  Completer<Partido>? enCurso;
  Object? errorAlReprogramar;
  final llamadas = <String>[];

  @override
  Future<List<Partido>> listar() async => partidos;

  @override
  Future<List<Partido>> listarParticipando() async => [];

  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async => partidos;

  @override
  Future<void> registrarEvento(String evento, Map<String, Object?> props) async {
    eventos.add(evento);
    if (evento == 'tarea_fallida') fallos.add(props['motivo'] as String);
  }

  @override
  Future<Partido> completarEquipo(int id) => (enCurso = Completer()).future;

  @override
  Future<Partido> reabrir(int id) => (enCurso = Completer()).future;

  @override
  Future<Partido> reprogramar(
    int id, {
    DateTime? fecha,
    String? ubicacion,
    required String motivo,
  }) async {
    throw errorAlReprogramar!;
  }

  @override
  Future<Partido> salir(int id) async {
    llamadas.add('salir $id');
    return partidos.first;
  }
}

Partido _partido({
  String estado = 'cupos abiertos',
  String? tiempo,
  List<UsuarioPartido> participantes = const [],
}) => Partido(
  id: 1,
  nombre: 'Fulbito',
  cantidadJugadores: 4,
  ubicacion: 'Cancha',
  tiempoMin: tiempo,
  fecha: DateTime.now().add(const Duration(days: 3)),
  estado: estado,
  deporte: 'futbol',
  organizador: const UsuarioPartido(id: 1, nombre: 'Org'),
  participantes: participantes,
  cantidadParticipantes: participantes.length,
);

Future<_Servicio> _misPartidos(
  WidgetTester tester,
  List<Partido> partidos, {
  Usuario? usuario,
}) async {
  _telefono(tester);
  final servicio = _Servicio(partidos);
  await tester.pumpWidget(
    MaterialApp(
      home: ListPartidoView(partidoService: servicio, usuario: usuario),
    ),
  );
  await tester.pumpAndSettle();
  return servicio;
}

void main() {
  group('Inicio', () {
    for (final (clave, titulo) in [
      ('boton-mi-cuenta', 'Mi cuenta'),
      ('boton-mis-partidos', 'Mis partidos'),
      ('boton-explorar-partidos', 'Explorar partidos'),
      ('boton-mi-historial', 'Mi historial'),
    ]) {
      testWidgets('abre $titulo', (tester) async {
        // Las pantallas reales leen la sesión desde el almacenamiento seguro.
        FlutterSecureStorage.setMockInitialValues({});
        _telefono(tester);
        await tester.pumpWidget(
          MaterialApp(home: HomeView(user: _yo, authService: AuthService())),
        );
        await tester.tap(find.byKey(Key(clave)));
        // La pantalla sigue cargando (no hay red en las pruebas): se espera un
        // tiempo fijo.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(titulo)),
          findsOneWidget,
        );
      });
    }
  });

  group('Formulario de partido', () {
    testWidgets('al crear, avisa qué falta: fecha y después los campos', (
      tester,
    ) async {
      final servicio = await _misPartidos(tester, []);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(servicio.eventos, contains('partido_creacion_iniciada'));

      await tester.tap(find.byKey(const Key('boton-guardar-partido')));
      await tester.pumpAndSettle();
      expect(find.text('La fecha es obligatoria'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boton-elegir-fecha')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boton-guardar-partido')));
      await tester.pumpAndSettle();

      expect(find.text('Campo obligatorio'), findsWidgets);
      expect(servicio.fallos, ['FECHA_OBLIGATORIA', 'CAMPOS_INCOMPLETOS']);
    });

    testWidgets('al editar un partido con fecha pasada pide una futura', (
      tester,
    ) async {
      _telefono(tester);
      final fallos = <String>[];
      final pasado = Partido(
        id: 1,
        nombre: 'Viejo',
        cantidadJugadores: 4,
        ubicacion: 'Cancha',
        fecha: DateTime.now().subtract(const Duration(days: 2)),
        estado: 'cupos abiertos',
        deporte: 'futbol',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioPartido(partido: pasado, alFallar: fallos.add),
          ),
        ),
      );

      // Cambiar el deporte conserva la elección.
      await tester.tap(find.text('Fútbol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vóley').last);
      await tester.pumpAndSettle();
      expect(find.text('Vóley'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boton-guardar-partido')));
      await tester.pumpAndSettle();

      expect(find.text('La fecha debe ser futura'), findsOneWidget);
      expect(fallos, ['FECHA_NO_FUTURA']);
    });
  });

  group('Mis partidos', () {
    testWidgets('reprogramar sin cambios se registra como intento frenado', (
      tester,
    ) async {
      final servicio = await _misPartidos(tester, [_partido()]);

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reprogramar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-reprogramar-partido')));
      await tester.pumpAndSettle();

      expect(servicio.fallos, ['SIN_CAMBIOS']);
    });

    testWidgets('si reprogramar falla, muestra el error de la API', (tester) async {
      final servicio = await _misPartidos(tester, [_partido()]);
      servicio.errorAlReprogramar = Exception('No se pudo reprogramar');

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reprogramar').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campo-ubicacion-reprogramacion')),
        'Otra cancha',
      );
      await tester.enterText(
        find.byKey(const Key('campo-motivo-reprogramacion')),
        'Lluvia',
      );
      await tester.tap(find.byKey(const Key('confirmar-reprogramar-partido')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo reprogramar'), findsOneWidget);
    });

    testWidgets('mientras completa o reabre, el botón muestra que está cargando', (
      tester,
    ) async {
      final servicio = await _misPartidos(tester, [_partido()]);

      await tester.tap(find.byKey(const Key('boton-completar-partido')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-completar-partido')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('boton-completar-partido')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      servicio.partidos = [_partido(estado: 'equipo completo')];
      servicio.enCurso!.complete(servicio.partidos.first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('boton-reabrir-partido')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-reabrir-partido')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('boton-reabrir-partido')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      servicio.enCurso!.complete(servicio.partidos.first);
      await tester.pumpAndSettle();
    });

    testWidgets('con pestañas, la ayuda explica Organizo y Me uní', (tester) async {
      await _misPartidos(tester, [_partido()], usuario: _yo);

      await tester.tap(find.byTooltip('Ayuda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('En Organizo están los partidos'), findsOneWidget);
    });
  });

  group('Explorar', () {
    Future<_Servicio> abrir(WidgetTester tester) async {
      _telefono(tester);
      final servicio = _Servicio([
        _partido(estado: 'equipo completo', participantes: [_ana]),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: ExplorarPartidosView(usuario: _yo, partidoService: servicio),
        ),
      );
      await tester.pumpAndSettle();
      return servicio;
    }

    testWidgets('quien está unido puede salir después de confirmar', (tester) async {
      final servicio = await abrir(tester);

      await tester.tap(find.byKey(const Key('boton-salir-partido')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, ['salir 1']);
      expect(find.text('Saliste del partido'), findsOneWidget);
    });

    testWidgets('muestra y oculta quiénes juegan', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Ver participantes'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      await tester.tap(find.text('Ocultar participantes'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsNothing);
    });
  });

  testWidgets('un campo que pasa a ser contraseña se oculta', (tester) async {
    final controlador = TextEditingController(text: 'secreto');
    Widget campo(bool oculto) => MaterialApp(
      home: Scaffold(
        body: Input(
          etiqueta: 'Clave',
          controlador: controlador,
          ocultarTexto: oculto,
        ),
      ),
    );

    await tester.pumpWidget(campo(false));
    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText, isFalse);
    await tester.pumpWidget(campo(true));
    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText, isTrue);
  });

  testWidgets('la tarjeta muestra la duración cuando el partido la tiene', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarjetaPartido(partido: _partido(tiempo: '60'), organizador: 'Org'),
        ),
      ),
    );

    expect(find.text('60 min'), findsOneWidget);
  });
}
