import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

class FakePartidoService extends PartidoService {
  int eliminarLlamadas = 0;

  final partido = Partido(
    id: 1,
    nombre: 'Partido de prueba',
    cantidadJugadores: 10,
    ubicacion: 'Cancha central',
    fecha: null,
    estado: 'cupos abiertos',
    deporte: 'futbol',
  );

  @override
  Future<List<Partido>> listar() async => [partido];

  @override
  Future<void> eliminar(int id) async {
    eliminarLlamadas++;
  }
}

Future<FakePartidoService> abrirLista(WidgetTester tester) async {
  final service = FakePartidoService();
  await tester.pumpWidget(
    MaterialApp(home: ListPartidoView(partidoService: service)),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('las acciones aparecen debajo del contenido de la tarjeta', (
    tester,
  ) async {
    await abrirLista(tester);

    final estado = tester.getTopLeft(find.text('Estado: Cupos abiertos'));
    final completar = tester.getTopLeft(find.byKey(const Key('boton-completar-partido')));
    final editar = tester.getTopLeft(find.byIcon(Icons.edit));
    final eliminar = tester.getTopLeft(find.byIcon(Icons.delete));

    expect(completar.dy, greaterThan(estado.dy));
    expect(editar.dy, greaterThan(estado.dy));
    expect(eliminar.dy, greaterThan(estado.dy));
  });

  testWidgets('los botones conservan su comportamiento: eliminar confirma', (
    tester,
  ) async {
    final service = await abrirLista(tester);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(service.eliminarLlamadas, 0);
  });
}
