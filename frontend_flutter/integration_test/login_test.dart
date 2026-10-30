import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

// Requires the backend running with seed data (backend/seed.py).
const _email = 'jugador@unisport.test';
const _password = 'Seed1234';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test without a stored session.
    await AuthService().logout();
  });

  testWidgets('Jugador inicia sesión y ve su bienvenida', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), _email);
    await tester.enterText(campos.at(1), _password);
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('¡Bienvenido, Jugador Demo!'), findsOneWidget);
    expect(find.text(_email), findsOneWidget);
  });

  testWidgets('Jugador ingresa una contraseña incorrecta y ve el error',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), _email);
    await tester.enterText(campos.at(1), 'ClaveIncorrecta');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.textContaining('Bienvenido'), findsNothing);
  });
}
