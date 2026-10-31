import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
const _email = 'organizador@unisport.test';
const _password = 'Seed1234';

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

Future<void> _abrirMisPartidos(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), _email);
  await tester.enterText(campos.at(1), _password);
  await tester.tap(find.byKey(const Key('boton-ingresar')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  await tester.tap(find.byKey(const Key('boton-mis-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// The card of the seeded match [nombre], scrolled into view.
Future<Finder> _tarjeta(WidgetTester tester, String nombre) async {
  await _esperar(tester, find.byType(Card));
  final tarjeta = find.widgetWithText(Card, nombre);
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

/// Taps a button inside a card, scrolling it fully into view first: the card
/// can be only partly visible and its actions sit at the bottom.
Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Finder _texto(Finder tarjeta, String texto) =>
    find.descendant(of: tarjeta, matching: find.text(texto));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test without a stored session.
    await AuthService().logout();
  });

  testWidgets('Organizador edita la ubicación de su partido', (tester) async {
    await _abrirMisPartidos(tester);

    var tarjeta = await _tarjeta(tester, 'Fulbito del viernes');
    expect(_texto(tarjeta, 'Ubicación: Cancha Central'), findsOneWidget);
    await _tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.byTooltip('Editar partido')),
    );
    expect(find.text('Editar partido'), findsOneWidget);

    final campos = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(campos.at(1), 'Cancha Editada'); // Ubicación
    await tester.tap(find.byKey(const Key('boton-guardar-partido')));
    await _esperar(tester, find.text('Partido guardado'));
    expect(find.text('Partido guardado'), findsOneWidget);
    await _limpiarAvisos(tester);

    tarjeta = await _tarjeta(tester, 'Fulbito del viernes');
    expect(_texto(tarjeta, 'Ubicación: Cancha Editada'), findsOneWidget);
    expect(_texto(tarjeta, 'Ubicación: Cancha Central'), findsNothing);
  });

  testWidgets('Organizador completa su equipo y luego lo reabre',
      (tester) async {
    await _abrirMisPartidos(tester);

    var tarjeta = await _tarjeta(tester, 'Basket 3x3');
    expect(_texto(tarjeta, 'Estado: Cupos abiertos'), findsOneWidget);
    await _tocar(
      tester,
      find.descendant(
        of: tarjeta,
        matching: find.byKey(const Key('boton-completar-partido')),
      ),
    );
    await tester.tap(find.byKey(const Key('confirmar-completar-partido')));
    await _esperar(tester, find.text('Equipo completado'));
    expect(find.text('Equipo completado'), findsOneWidget);
    await _limpiarAvisos(tester);

    tarjeta = await _tarjeta(tester, 'Basket 3x3');
    expect(_texto(tarjeta, 'Estado: Equipo completo'), findsOneWidget);
    expect(
      find.descendant(
        of: tarjeta,
        matching: find.byKey(const Key('boton-completar-partido')),
      ),
      findsNothing,
    );

    await _tocar(
      tester,
      find.descendant(
        of: tarjeta,
        matching: find.byKey(const Key('boton-reabrir-partido')),
      ),
    );
    await tester.tap(find.byKey(const Key('confirmar-reabrir-partido')));
    await _esperar(tester, find.text('Equipo reabierto'));
    expect(find.text('Equipo reabierto'), findsOneWidget);
    await _limpiarAvisos(tester);

    tarjeta = await _tarjeta(tester, 'Basket 3x3');
    expect(_texto(tarjeta, 'Estado: Cupos abiertos'), findsOneWidget);
  });

  testWidgets('Organizador cancela eliminar y el partido se queda',
      (tester) async {
    await _abrirMisPartidos(tester);

    final tarjeta = await _tarjeta(tester, 'Voley de tarde');
    await _tocar(
      tester,
      find.descendant(
        of: tarjeta,
        matching: find.byTooltip('Eliminar partido'),
      ),
    );
    expect(find.text('¿Quieres eliminar este partido?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres eliminar este partido?'), findsNothing);
    expect(await _tarjeta(tester, 'Voley de tarde'), findsOneWidget);
  });

  testWidgets('Organizador elimina un partido y desaparece de la lista',
      (tester) async {
    await _abrirMisPartidos(tester);

    final tarjeta = await _tarjeta(tester, 'Voley de tarde');
    await _tocar(
      tester,
      find.descendant(
        of: tarjeta,
        matching: find.byTooltip('Eliminar partido'),
      ),
    );
    await tester.tap(find.byKey(const Key('confirmar-eliminar-partido')));
    await _esperar(tester, find.text('Partido eliminado'));
    expect(find.text('Partido eliminado'), findsOneWidget);
    await _limpiarAvisos(tester);

    expect(find.widgetWithText(Card, 'Voley de tarde'), findsNothing);
  });
}
