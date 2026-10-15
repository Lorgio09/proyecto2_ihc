import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

class FakePartidoService extends PartidoService {
  int completarLlamadas = 0;

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
  Future<Partido> completarEquipo(int id) async {
    completarLlamadas++;
    return Partido(
      id: partido.id,
      nombre: partido.nombre,
      cantidadJugadores: partido.cantidadJugadores,
      ubicacion: partido.ubicacion,
      fecha: partido.fecha,
      estado: 'equipo completo',
      deporte: partido.deporte,
    );
  }
}

void main() {
  testWidgets('cancelar completar equipo no llama al servicio', (tester) async {
    final service = FakePartidoService();
    await tester.pumpWidget(
      MaterialApp(
        home: ListPartidoView(partidoService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Completar equipo'));
    await tester.pumpAndSettle();
    expect(find.text('Al completar el equipo se cerrarán los cupos y otros usuarios no podrán unirse al partido. ¿Quieres continuar?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(service.completarLlamadas, 0);
  });

  testWidgets('confirmar completar equipo llama al servicio', (tester) async {
    final service = FakePartidoService();
    await tester.pumpWidget(
      MaterialApp(
        home: ListPartidoView(partidoService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Completar equipo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completar equipo').last);
    await tester.pumpAndSettle();

    expect(service.completarLlamadas, 1);
  });
}
