import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

class FakeCargaPartidoService extends PartidoService {
  int listarLlamadas = 0;
  bool debeFallar = true;

  @override
  Future<List<Partido>> listar() async {
    listarLlamadas++;
    if (debeFallar) throw Exception('error de red');
    return const [];
  }

  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async {
    listarLlamadas++;
    if (debeFallar) throw Exception('error de red');
    return const [];
  }
}

void main() {
  testWidgets('Mis partidos permite reintentar la carga', (tester) async {
    final service = FakeCargaPartidoService();
    await tester.pumpWidget(
      MaterialApp(home: ListPartidoView(partidoService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar tus partidos'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    service.debeFallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(service.listarLlamadas, 2);
  });

  testWidgets('Explorar partidos permite reintentar la carga', (tester) async {
    final service = FakeCargaPartidoService();
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
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudieron cargar los partidos disponibles'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    service.debeFallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(service.listarLlamadas, 2);
  });
}
