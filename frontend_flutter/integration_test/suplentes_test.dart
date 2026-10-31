import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
// "Duelo de dos" is seeded with room for two players.
const _password = 'Seed1234';
const _partido = 'Duelo de dos';
const _titular1 = 'jugador2@unisport.test';
const _titular2 = 'jugador@unisport.test';
const _suplente = 'jugador3@unisport.test';
const _organizador = 'organizador@unisport.test';

/// A snackbar is dismissed on its own, so pumpAndSettle would wait past it.
Future<void> _esperar(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// A snackbar outlives pumpAndSettle and can cover the next tap target.
Future<void> _limpiarAvisos(WidgetTester tester) async {
  final scaffold = find.byType(Scaffold).evaluate().last;
  ScaffoldMessenger.of(scaffold).clearSnackBars();
  await tester.pumpAndSettle();
}

Future<void> _entrar(WidgetTester tester, String email) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), email);
  await tester.enterText(campos.at(1), _password);
  await tester.tap(find.byKey(const Key('boton-ingresar')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _cerrarSesion(WidgetTester tester) async {
  await _limpiarAvisos(tester);
  await tester.tap(find.byTooltip('Cerrar sesión'));
  await tester.pumpAndSettle();
}

Future<void> _abrirExplorar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-explorar-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// The match's card, scrolled fully into view.
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
  await tester.ensureVisible(tarjeta);
  await tester.pumpAndSettle();
  return tarjeta;
}

Finder _texto(Finder tarjeta, String texto) =>
    find.descendant(of: tarjeta, matching: find.text(texto));

Finder _boton(Finder tarjeta, String clave) =>
    find.descendant(of: tarjeta, matching: find.byKey(Key(clave)));

Future<void> _unirse(WidgetTester tester, String aviso) async {
  final tarjeta = await _tarjeta(tester);
  await tester.tap(_boton(tarjeta, 'boton-unirse-partido'));
  await _esperar(tester, find.text(aviso));
  expect(find.text(aviso), findsOneWidget);
  await _limpiarAvisos(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test without a stored session.
    await AuthService().logout();
  });

  testWidgets(
      'Con el cupo lleno el tercero queda de suplente y sube cuando un titular sale',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Two players take the two holder spots.
    await _entrar(tester, _titular1);
    await _abrirExplorar(tester);
    await _unirse(tester, 'Te uniste al partido');
    var tarjeta = await _tarjeta(tester);
    expect(_texto(tarjeta, 'Cupos: 1/2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _cerrarSesion(tester);

    await _entrar(tester, _titular2);
    await _abrirExplorar(tester);
    await _unirse(tester, 'Te uniste al partido');
    tarjeta = await _tarjeta(tester);
    expect(_texto(tarjeta, 'Cupos: 2/2'), findsOneWidget);
    expect(_texto(tarjeta, 'Estado: Equipo completo'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _cerrarSesion(tester);

    // The third player finds the team full and joins as a substitute.
    await _entrar(tester, _suplente);
    await _abrirExplorar(tester);
    tarjeta = await _tarjeta(tester);
    expect(_texto(tarjeta, 'Unirse como suplente'), findsOneWidget);
    await _unirse(tester, 'Te uniste como suplente');
    tarjeta = await _tarjeta(tester);
    expect(_texto(tarjeta, 'Eres suplente (posición 1)'), findsOneWidget);
    expect(_texto(tarjeta, 'Suplentes: 1'), findsOneWidget);
    expect(_texto(tarjeta, 'Cupos: 2/2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _cerrarSesion(tester);

    // The organizer sees holders and substitutes apart.
    await _entrar(tester, _organizador);
    await tester.tap(find.byKey(const Key('boton-mis-partidos')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _esperar(tester, find.byType(Card));
    tarjeta = find.widgetWithText(Card, _partido);
    await tester.scrollUntilVisible(
      tarjeta,
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.descendant(
      of: tarjeta,
      matching: find.text('Ver participantes'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: tarjeta, matching: find.text('Ver participantes')),
    );
    await tester.pumpAndSettle();
    expect(_texto(tarjeta, 'Segundo Jugador, Jugador Demo'), findsOneWidget);
    expect(_texto(tarjeta, 'Suplentes: Tercer Jugador'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _cerrarSesion(tester);

    // A holder leaves: the substitute takes the spot.
    await _entrar(tester, _titular1);
    await _abrirExplorar(tester);
    tarjeta = await _tarjeta(tester);
    await tester.tap(_boton(tarjeta, 'boton-salir-partido'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
    await _esperar(tester, find.text('Saliste del partido'));
    await _limpiarAvisos(tester);
    tarjeta = await _tarjeta(tester);
    expect(_texto(tarjeta, 'Cupos: 2/2'), findsOneWidget);
    expect(_texto(tarjeta, 'Suplentes: 1'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _cerrarSesion(tester);

    // The former substitute is now a holder, and the history says so.
    await _entrar(tester, _suplente);
    await _abrirExplorar(tester);
    tarjeta = await _tarjeta(tester);
    expect(_texto(tarjeta, 'Cupos: 2/2'), findsOneWidget);
    expect(find.descendant(
      of: tarjeta,
      matching: find.textContaining('Eres suplente'),
    ), findsNothing);
    expect(_boton(tarjeta, 'boton-salir-partido'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton-mi-historial')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Te uniste como suplente'), findsOneWidget);
    expect(find.text('Pasaste a titular'), findsOneWidget);
  });
}
