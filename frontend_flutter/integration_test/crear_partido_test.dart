import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

// Requires the backend running with seed data (backend/seed.py).
const _email = 'organizador@unisport.test';
const _password = 'Seed1234';

Future<void> _iniciarSesion(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), _email);
  await tester.enterText(campos.at(1), _password);
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _abrirFormularioNuevoPartido(WidgetTester tester) async {
  await tester.tap(find.text('Mis partidos'));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  expect(find.text('Nuevo partido'), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test without a stored session.
    await AuthService().logout();
  });

  testWidgets('Organizador crea un partido y lo ve en Mis partidos',
      (tester) async {
    // A unique name keeps the assertion exact across repeated runs.
    final nombre = 'Partido E2E ${DateTime.now().millisecondsSinceEpoch}';

    await _iniciarSesion(tester);
    await _abrirFormularioNuevoPartido(tester);

    final campos = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(campos.at(0), nombre); // Nombre
    await tester.enterText(campos.at(1), 'Cancha E2E'); // Ubicación
    await tester.enterText(campos.at(2), '10'); // Cantidad de jugadores

    await tester.tap(find.text('Elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Scope to the list tile: a confirmation snackbar may repeat the name.
    final tarjeta = find.descendant(
      of: find.byType(ListTile),
      matching: find.text(nombre),
    );
    await tester.scrollUntilVisible(
      tarjeta,
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tarjeta, findsOneWidget);
    expect(find.text('Ubicación: Cancha E2E'), findsWidgets);
  });

  testWidgets('Organizador intenta guardar sin fecha y ve el error',
      (tester) async {
    await _iniciarSesion(tester);
    await _abrirFormularioNuevoPartido(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('La fecha es obligatoria'), findsOneWidget);
    expect(find.text('Nuevo partido'), findsOneWidget);
  });
}
