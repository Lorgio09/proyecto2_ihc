import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';

class FakeRespuestasEnDesorden extends PartidoService {
  final respuestas = <Completer<List<Partido>>>[];

  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) {
    final respuesta = Completer<List<Partido>>();
    respuestas.add(respuesta);
    return respuesta.future;
  }
}

void main() {
  testWidgets('Una respuesta vieja no pisa el resultado de la búsqueda',
      (tester) async {
    final service = FakeRespuestasEnDesorden();
    await tester.pumpWidget(
      MaterialApp(
        home: ExplorarPartidosView(
          usuario: const Usuario(
            id: 99,
            nombre: 'Usuario',
            email: 'usuario@test.com',
          ),
          partidoService: service,
        ),
      ),
    );
    await tester.pump();

    // The search is sent while the first load is still pending.
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar por nombre'),
      'zzz',
    );
    await tester.tap(find.byTooltip('Buscar partidos'));
    await tester.pump();
    expect(service.respuestas, hasLength(2));

    // The search answers first (no results); the first load answers late.
    service.respuestas[1].complete(const []);
    await tester.pump();
    service.respuestas[0].complete(const [
      Partido(
        id: 1,
        nombre: 'Partido viejo',
        cantidadJugadores: 4,
        ubicacion: 'Cancha',
        estado: 'abierto',
        deporte: 'futbol',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Partido viejo'), findsNothing);
  });
}
