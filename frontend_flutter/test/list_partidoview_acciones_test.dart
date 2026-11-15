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
  testWidgets('la acción principal va debajo del contenido y el resto en el menú', (
    tester,
  ) async {
    await abrirLista(tester);

    final cupos = tester.getTopLeft(find.text('Cupos: 0/10'));
    final completar = tester.getTopLeft(
      find.byKey(const Key('boton-completar-partido')),
    );
    expect(completar.dy, greaterThan(cupos.dy));

    // Editing and deleting live in the "⋮" menu, not as loose icons (H8).
    expect(find.byIcon(Icons.edit), findsNothing);
    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pumpAndSettle();
    expect(find.text('Reprogramar'), findsOneWidget);
    expect(find.text('Resultado del partido'), findsOneWidget);
    expect(find.text('Editar partido'), findsOneWidget);
    expect(find.text('Eliminar partido'), findsOneWidget);
  });

  testWidgets('los botones conservan su comportamiento: eliminar confirma', (
    tester,
  ) async {
    final service = await abrirLista(tester);

    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar partido'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(service.eliminarLlamadas, 0);
  });
}
