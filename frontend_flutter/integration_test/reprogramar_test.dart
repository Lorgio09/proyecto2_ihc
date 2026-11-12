import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_analitica.dart';
import 'helpers_resultado.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
// mis_partidos_test deletes "Voley de tarde"; this one is only edited there.
const _partido = 'Fulbito del viernes';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets('El organizador reprograma el lugar con un motivo', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await entrar(tester, organizador);
    final antes = await conteoEventos();

    await tester.tap(find.byKey(const Key('boton-mis-partidos')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    final tarjeta = find.widgetWithText(Card, _partido);
    await mostrar(tester, tarjeta);
    final reprogramar = find.descendant(
      of: tarjeta,
      matching: find.byKey(const Key('boton-reprogramar-partido')),
    );
    await tester.ensureVisible(reprogramar);
    await tester.pumpAndSettle();
    await tester.tap(reprogramar);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('campo-ubicacion-reprogramacion')),
      'Coliseo techado',
    );
    await tester.enterText(
      find.byKey(const Key('campo-motivo-reprogramacion')),
      'Pronóstico de lluvia',
    );
    await tester.tap(find.byKey(const Key('confirmar-reprogramar-partido')));
    await esperar(tester, find.text('Reprogramado: Pronóstico de lluvia'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await mostrar(tester, find.widgetWithText(Card, _partido));
    expect(find.text('Ubicación: Coliseo techado'), findsOneWidget);
    expect(find.text('Reprogramado: Pronóstico de lluvia'), findsOneWidget);
    await expectEventos(antes, {
      'reprogramacion_iniciada': 1,
      'partido_reprogramado': 1,
    });
  });
}
