import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'pantalla.dart';

// Requiere el backend corriendo con datos de seed (backend/seed.py).
const _email = 'jugador@unisport.test';
const _password = 'Seed1234';

void main() {
  iniciarComoTelefono();

  setUp(() async {
    // Cada prueba empieza sin sesión guardada.
    await AuthService().logout();
  });

  testWidgets('Jugador inicia sesión y ve su bienvenida', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), _email);
    await tester.enterText(campos.at(1), _password);
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('¡Bienvenido, Jugador Demo!'), findsOneWidget);
    expect(find.text(_email), findsOneWidget);
  });

  testWidgets('Jugador ingresa una contraseña incorrecta y ve el error', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), _email);
    await tester.enterText(campos.at(1), 'ClaveIncorrecta');
    await tester.tap(find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    expect(find.byKey(const Key('boton-ingresar')), findsOneWidget);
    expect(find.textContaining('Bienvenido'), findsNothing);
  });
}
