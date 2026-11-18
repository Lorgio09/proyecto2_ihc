import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_analitica.dart';
import 'pantalla.dart';

// Requiere el backend corriendo con datos de seed (backend/seed.py).
const _email = 'organizador@unisport.test';
const _password = 'Seed1234';

Future<void> _iniciarSesion(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), _email);
  await tester.enterText(campos.at(1), _password);
  await tester.tap(find.byKey(const Key('boton-ingresar')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _abrirFormularioNuevoPartido(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-mis-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  // El título del diálogo; el botón que lo abre dice lo mismo.
  expect(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Nuevo partido'),
    ),
    findsOneWidget,
  );
}

void main() {
  iniciarComoTelefono();

  setUp(() async {
    // Cada prueba empieza sin sesión guardada.
    await AuthService().logout();
  });

  testWidgets('Organizador crea un partido y lo ve en Mis partidos', (
    tester,
  ) async {
    // Un nombre único mantiene exacta la verificación en ejecuciones repetidas.
    final nombre = 'Partido E2E ${DateTime.now().millisecondsSinceEpoch}';

    await _iniciarSesion(tester);
    final antes = await conteoEventos();
    await _abrirFormularioNuevoPartido(tester);

    final campos = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(campos.at(0), nombre); // Nombre
    await tester.enterText(campos.at(1), 'Cancha E2E'); // Ubicación
    await tester.enterText(campos.at(2), '10'); // Cantidad de jugadores

    await tester.tap(find.byKey(const Key('boton-elegir-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton-guardar-partido')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Limitar a la tarjeta del partido: un snackbar de confirmación puede
    // repetir el nombre.
    final tarjeta = find.descendant(
      of: find.byType(Card),
      matching: find.text(nombre),
    );
    await tester.scrollUntilVisible(
      tarjeta,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tarjeta, findsOneWidget);
    expect(find.text('Cancha E2E'), findsWidgets);
    await expectEventos(antes, {
      'partido_creacion_iniciada': 1,
      'partido_creado': 1,
    });
  });

  testWidgets('Organizador intenta guardar sin fecha y ve el error', (
    tester,
  ) async {
    await _iniciarSesion(tester);
    final antes = await conteoEventos();
    await _abrirFormularioNuevoPartido(tester);

    await tester.tap(find.byKey(const Key('boton-guardar-partido')));
    await tester.pumpAndSettle();

    expect(find.text('La fecha es obligatoria'), findsOneWidget);
    // El título del diálogo; el botón que lo abre dice lo mismo.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nuevo partido'),
      ),
      findsOneWidget,
    );
    // Iniciado pero bloqueado por la validación: ningún éxito, un fallo.
    await expectEventos(antes, {
      'partido_creacion_iniciada': 1,
      'tarea_fallida': 1,
      'partido_creado': 0,
    });
  });
}
