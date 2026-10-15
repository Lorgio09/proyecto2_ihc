import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

class FakeListPartidoService extends PartidoService {
  FakeListPartidoService(this.resultado);

  final List<Partido> resultado;

  @override
  Future<List<Partido>> listar() async => resultado;
}

Partido partido({
  required int id,
  required String nombre,
  required String ubicacion,
  required String estado,
}) {
  return Partido(
    id: id,
    nombre: nombre,
    cantidadJugadores: 10,
    ubicacion: ubicacion,
    estado: estado,
    deporte: 'futbol',
  );
}

final partidosPrueba = [
  partido(
    id: 1,
    nombre: 'Oriente',
    ubicacion: 'Centro',
    estado: 'cupos abiertos',
  ),
  partido(
    id: 2,
    nombre: 'Blooming',
    ubicacion: 'Norte',
    estado: 'equipo completo',
  ),
  partido(
    id: 3,
    nombre: 'Partido familiar',
    ubicacion: 'Centro',
    estado: 'cupos abiertos',
  ),
];

Future<void> mostrarLista(WidgetTester tester, List<Partido> partidos) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ListPartidoView(partidoService: FakeListPartidoService(partidos)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('busca partidos por nombre', (tester) async {
    await mostrarLista(tester, partidosPrueba);

    await tester.enterText(find.byType(TextField), 'oriente');
    await tester.pump();

    expect(find.text('Blooming'), findsOneWidget);
    await tester.tap(find.text('Buscar partidos'));
    await tester.pump();
    expect(find.text('Oriente'), findsOneWidget);
    expect(find.text('Blooming'), findsNothing);
    expect(find.text('Partido familiar'), findsNothing);
  });

  testWidgets('busca por ubicación sin distinguir mayúsculas', (tester) async {
    await mostrarLista(tester, partidosPrueba);

    await tester.enterText(find.byType(TextField), 'nOrTe');
    await tester.pump();

    expect(find.text('Oriente'), findsOneWidget);
    await tester.tap(find.text('Buscar partidos'));
    await tester.pump();
    expect(find.text('Blooming'), findsOneWidget);
    expect(find.text('Oriente'), findsNothing);
  });

  testWidgets('filtra por estado y combina filtros', (tester) async {
    await mostrarLista(tester, partidosPrueba);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipo completo').last);
    await tester.pump();

    expect(find.text('Oriente'), findsOneWidget);
    await tester.tap(find.text('Buscar partidos'));
    await tester.pump();
    expect(find.text('Blooming'), findsOneWidget);
    expect(find.text('Oriente'), findsNothing);

    await tester.enterText(find.byType(TextField), 'bloom');
    await tester.pump();
    expect(find.text('Blooming'), findsOneWidget);
  });

  testWidgets('limpiar filtros restaura todos los partidos', (tester) async {
    await mostrarLista(tester, partidosPrueba);
    await tester.enterText(find.byType(TextField), 'oriente');
    await tester.pump();
    await tester.tap(find.text('Buscar partidos'));
    await tester.pump();

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Partido familiar'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Partido familiar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Oriente'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Oriente'), findsOneWidget);
  });

  testWidgets('diferencia lista vacía de filtros sin resultados', (
    tester,
  ) async {
    await mostrarLista(tester, const []);
    expect(find.text('No tienes partidos todavía'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await mostrarLista(tester, partidosPrueba);
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pump();
    await tester.tap(find.text('Buscar partidos'));
    await tester.pump();
    expect(
      find.text('No encontramos partidos con estos filtros'),
      findsOneWidget,
    );
  });

  testWidgets('mantiene las acciones en los partidos visibles', (tester) async {
    await mostrarLista(tester, partidosPrueba);

    await tester.enterText(find.byType(TextField), 'oriente');
    await tester.pump();
    await tester.tap(find.text('Buscar partidos'));
    await tester.pump();

    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.text('Completar equipo'), findsOneWidget);
  });
}
