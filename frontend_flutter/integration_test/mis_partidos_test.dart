import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'pantalla.dart';

// Requiere el backend corriendo con datos de seed (backend/seed.py --reset).
const _email = 'organizador@unisport.test';
const _password = 'Seed1234';

/// Un snackbar se cierra solo, así que pumpAndSettle esperaría hasta después de
/// que desaparezca.
Future<void> _esperar(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Un snackbar sigue visible después de pumpAndSettle y puede tapar el
/// siguiente botón a tocar.
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

/// La tarjeta del partido de seed [nombre], desplazada hasta quedar visible.
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

/// Toca un botón dentro de una tarjeta, desplazándola antes hasta verla
/// completa: la tarjeta puede verse solo en parte y sus acciones están abajo.
Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

/// Las acciones secundarias están en el menú "⋮" de la tarjeta.
Future<void> _opcionDelMenu(
  WidgetTester tester,
  Finder tarjeta,
  String opcion,
) async {
  await _tocar(
    tester,
    find.descendant(of: tarjeta, matching: find.byTooltip('Más acciones')),
  );
  await tester.tap(find.text(opcion));
  await tester.pumpAndSettle();
}

Finder _texto(Finder tarjeta, String texto) =>
    find.descendant(of: tarjeta, matching: find.text(texto));

void main() {
  iniciarComoTelefono();

  setUp(() async {
    // Cada prueba empieza sin sesión guardada.
    await AuthService().logout();
  });

  testWidgets('Organizador edita la ubicación de su partido', (tester) async {
    await _abrirMisPartidos(tester);

    var tarjeta = await _tarjeta(tester, 'Fulbito del viernes');
    expect(_texto(tarjeta, 'Cancha Central'), findsOneWidget);
    await _opcionDelMenu(tester, tarjeta, 'Editar partido');
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
    expect(_texto(tarjeta, 'Cancha Editada'), findsOneWidget);
    expect(_texto(tarjeta, 'Cancha Central'), findsNothing);
  });

  testWidgets('Organizador completa su equipo y luego lo reabre', (
    tester,
  ) async {
    await _abrirMisPartidos(tester);

    var tarjeta = await _tarjeta(tester, 'Basket 3x3');
    expect(_texto(tarjeta, 'Cupos abiertos'), findsOneWidget);
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
    expect(_texto(tarjeta, 'Equipo completo'), findsOneWidget);
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
    expect(_texto(tarjeta, 'Cupos abiertos'), findsOneWidget);
  });

  testWidgets('Organizador cancela eliminar y el partido se queda', (
    tester,
  ) async {
    await _abrirMisPartidos(tester);

    final tarjeta = await _tarjeta(tester, 'Voley de tarde');
    await _opcionDelMenu(tester, tarjeta, 'Eliminar partido');
    expect(find.text('Eliminar Voley de tarde'), findsOneWidget);
    expect(find.text('No se puede deshacer.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancelar-confirmacion')));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar Voley de tarde'), findsNothing);
    expect(await _tarjeta(tester, 'Voley de tarde'), findsOneWidget);
  });

  testWidgets('Organizador elimina un partido y desaparece de la lista', (
    tester,
  ) async {
    await _abrirMisPartidos(tester);

    final tarjeta = await _tarjeta(tester, 'Voley de tarde');
    await _opcionDelMenu(tester, tarjeta, 'Eliminar partido');
    await tester.tap(find.byKey(const Key('confirmar-eliminar-partido')));
    await _esperar(tester, find.text('Partido eliminado'));
    expect(find.text('Partido eliminado'), findsOneWidget);
    await _limpiarAvisos(tester);

    expect(find.widgetWithText(Card, 'Voley de tarde'), findsNothing);
  });
}
