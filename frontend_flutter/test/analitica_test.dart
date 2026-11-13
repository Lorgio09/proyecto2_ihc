import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';

const _yo = Usuario(id: 7, nombre: 'Yo', email: 'yo@unisport.test');

Partido _partido({List<UsuarioPartido> titulares = const []}) {
  return Partido(
    id: 1,
    nombre: 'Fulbito',
    cantidadJugadores: 10,
    ubicacion: 'Cancha central',
    fecha: DateTime.now().add(const Duration(days: 2)),
    estado: 'cupos abiertos',
    organizador: const UsuarioPartido(id: 99, nombre: 'Org'),
    participantes: titulares,
    cantidadParticipantes: titulares.length,
    cuposDisponibles: 10 - titulares.length,
    deporte: 'basquet',
  );
}

class _Servicio extends PartidoService {
  Partido partido = _partido();
  final eventos = <(String, Map<String, Object?>)>[];

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
  Future<Partido> unirse(int id) async {
    partido = _partido(titulares: const [UsuarioPartido(id: 7, nombre: 'Yo')]);
    return partido;
  }

  @override
  Future<void> registrarEvento(
    String evento,
    Map<String, Object?> props,
  ) async {
    eventos.add((evento, props));
  }
}

void main() {
  testWidgets(
    'tocar Unirse registra union_iniciada una vez y sin datos personales',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final servicio = _Servicio();
      await tester.pumpWidget(
        MaterialApp(
          home: ExplorarPartidosView(usuario: _yo, partidoService: servicio),
        ),
      );
      await tester.pumpAndSettle();

      expect(servicio.eventos, isEmpty);

      await tester.ensureVisible(find.byKey(const Key('boton-unirse-partido')));
      await tester.tap(find.byKey(const Key('boton-unirse-partido')));
      await tester.pumpAndSettle();

      expect(servicio.eventos, hasLength(1));
      final (evento, props) = servicio.eventos.single;
      expect(evento, 'union_iniciada');
      expect(props, {'deporte': 'basquet'});
      expect(props.toString(), isNot(contains('@')));
    },
  );
}
