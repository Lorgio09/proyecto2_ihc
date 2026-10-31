import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
const _password = 'Seed1234';
const _partido = 'Futsal nocturno';

Future<void> _iniciarSesion(WidgetTester tester, String email) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), email);
  await tester.enterText(campos.at(1), _password);
  await tester.tap(find.byKey(const Key('boton-ingresar')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _abrirExplorar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-explorar-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// The seeded match's card, scrolled into view.
Future<Finder> _tarjeta(WidgetTester tester) async {
  await _esperar(tester, find.byType(Card));
  final tarjeta = find.widgetWithText(Card, _partido);
  await tester.scrollUntilVisible(
    tarjeta,
    300,
    scrollable: find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  return tarjeta;
}

/// Waits until [finder] appears. A snackbar is dismissed on its own, so
/// pumpAndSettle would wait past it and the assertion would miss it.
Future<void> _esperar(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder _en(Finder tarjeta, String clave) =>
    find.descendant(of: tarjeta, matching: find.byKey(Key(clave)));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test without a stored session.
    await AuthService().logout();
  });

  testWidgets('Jugador se une, lo ve en su historial y luego sale',
      (tester) async {
    await _iniciarSesion(tester, 'jugador@unisport.test');
    await _abrirExplorar(tester);

    var tarjeta = await _tarjeta(tester);
    expect(find.descendant(of: tarjeta, matching: find.text('Cupos: 0/8')),
        findsOneWidget);
    await tester.tap(_en(tarjeta, 'boton-unirse-partido'));
    await _esperar(tester, find.text('Te uniste al partido'));

    expect(find.text('Te uniste al partido'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    tarjeta = await _tarjeta(tester);
    expect(find.descendant(of: tarjeta, matching: find.text('Cupos: 1/8')),
        findsOneWidget);
    expect(_en(tarjeta, 'boton-salir-partido'), findsOneWidget);
    expect(_en(tarjeta, 'boton-unirse-partido'), findsNothing);

    // The join shows up in the history.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton-mi-historial')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(_partido), findsOneWidget);
    expect(find.text('Te uniste al partido'), findsOneWidget);

    // Leave the match and the slot is released.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _abrirExplorar(tester);
    tarjeta = await _tarjeta(tester);
    await tester.tap(_en(tarjeta, 'boton-salir-partido'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
    await _esperar(tester, find.text('Saliste del partido'));

    expect(find.text('Saliste del partido'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    tarjeta = await _tarjeta(tester);
    expect(find.descendant(of: tarjeta, matching: find.text('Cupos: 0/8')),
        findsOneWidget);
    expect(_en(tarjeta, 'boton-unirse-partido'), findsOneWidget);
  });

  testWidgets('Organizador no ve sus propios partidos en Explorar',
      (tester) async {
    await _iniciarSesion(tester, 'organizador@unisport.test');
    await _abrirExplorar(tester);
    await _esperar(tester, find.text('Buscar por nombre'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.widgetWithText(Card, _partido), findsNothing);
    expect(find.byKey(const Key('boton-unirse-partido')), findsNothing);
  });
}
