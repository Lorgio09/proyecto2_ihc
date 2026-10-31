import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
// Accounts created here use the e2e-*@unisport.test pattern, which the
// seed's --reset removes.
const _password = 'Seed1234';

String _emailUnico() =>
    'e2e-${DateTime.now().millisecondsSinceEpoch}@unisport.test';

/// A snackbar is dismissed on its own, so pumpAndSettle would wait past it.
Future<void> _esperar(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// A snackbar outlives pumpAndSettle (its timer schedules no frames) and can
/// cover the button the next step taps, so dismiss it first.
Future<void> _limpiarAvisos(WidgetTester tester) async {
  final scaffold = find.byType(Scaffold).evaluate().last;
  ScaffoldMessenger.of(scaffold).clearSnackBars();
  await tester.pumpAndSettle();
}

/// Creates an account through the service, then drops its session.
Future<String> _crearCuenta() async {
  final email = _emailUnico();
  final servicio = AuthService();
  await servicio.registro('Cuenta E2E', email, _password, null);
  await servicio.logout();
  return email;
}

Future<void> _abrirLogin(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

Future<void> _iniciarSesion(
  WidgetTester tester,
  String email,
  String password,
) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), email);
  await tester.enterText(campos.at(1), password);
  await tester.tap(find.byKey(const Key('boton-ingresar')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test without a stored session.
    await AuthService().logout();
  });

  testWidgets('Visitante se registra y llega a su bienvenida', (tester) async {
    final email = _emailUnico();
    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('enlace-registro')));
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Cuenta Nueva'); // Nombre
    await tester.enterText(campos.at(1), email); // Email
    await tester.enterText(campos.at(2), _password); // Contraseña
    await tester.enterText(campos.at(3), '70000099'); // Teléfono
    await tester.tap(find.byKey(const Key('boton-registrarme')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('¡Bienvenido, Cuenta Nueva!'), findsOneWidget);
    expect(find.text(email), findsOneWidget);
  });

  testWidgets('Visitante envía el registro vacío y ve el aviso',
      (tester) async {
    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('enlace-registro')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton-registrarme')));
    await _esperar(tester, find.text('Completa los campos obligatorios.'));

    expect(find.text('Completa los campos obligatorios.'), findsOneWidget);
    expect(find.byKey(const Key('boton-registrarme')), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Visitante se registra con un email ya usado y ve el error',
      (tester) async {
    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('enlace-registro')));
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Repetido');
    await tester.enterText(campos.at(1), 'jugador@unisport.test');
    await tester.enterText(campos.at(2), _password);
    await tester.tap(find.byKey(const Key('boton-registrarme')));
    await _esperar(tester, find.text('El email ya está registrado'));

    expect(find.text('El email ya está registrado'), findsOneWidget);
    expect(find.textContaining('Bienvenido'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Usuario recupera su contraseña y entra con la nueva',
      (tester) async {
    final email = await _crearCuenta();
    const nueva = 'Nueva1234';

    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('enlace-olvide-contrasena')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.tap(find.byKey(const Key('boton-continuar-recuperacion')));
    await _esperar(tester, find.text('Código enviado. Usa el código 123456.'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _limpiarAvisos(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.byKey(const Key('boton-continuar-recuperacion')));
    await tester.pumpAndSettle();

    await _limpiarAvisos(tester);
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), nueva); // Nueva contraseña
    await tester.enterText(campos.at(1), nueva); // Confirmar
    await tester.tap(find.byKey(const Key('boton-cambiar-contrasena')));
    await _esperar(tester, find.byKey(const Key('boton-ingresar')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _iniciarSesion(tester, email, nueva);
    expect(find.text('¡Bienvenido, Cuenta E2E!'), findsOneWidget);
  });

  testWidgets('Usuario escribe un código de recuperación incorrecto',
      (tester) async {
    final email = await _crearCuenta();

    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('enlace-olvide-contrasena')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.tap(find.byKey(const Key('boton-continuar-recuperacion')));
    await _esperar(tester, find.text('Código enviado. Usa el código 123456.'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _limpiarAvisos(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '000000');
    await tester.tap(find.byKey(const Key('boton-continuar-recuperacion')));
    await _esperar(tester, find.text('El codigo ingresado no es correcto.'));

    expect(find.text('El codigo ingresado no es correcto.'), findsOneWidget);
    expect(find.byKey(const Key('boton-cambiar-contrasena')), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Usuario cambia su contraseña con sesión iniciada',
      (tester) async {
    final email = await _crearCuenta();
    const nueva = 'Cambiada1234';

    await _abrirLogin(tester);
    await _iniciarSesion(tester, email, _password);
    await tester.tap(find.byTooltip('Cambiar contraseña'));
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), _password); // Actual
    await tester.enterText(campos.at(1), nueva); // Nueva
    await tester.enterText(campos.at(2), nueva); // Confirmar
    await tester.tap(find.byKey(const Key('boton-cambiar-contrasena')));
    await _esperar(tester, find.text('Contraseña actualizada correctamente.'));
    expect(find.text('Contraseña actualizada correctamente.'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The old password no longer works; the new one does.
    await _limpiarAvisos(tester);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await _iniciarSesion(tester, email, _password);
    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    await _limpiarAvisos(tester);
    await _iniciarSesion(tester, email, nueva);
    expect(find.text('¡Bienvenido, Cuenta E2E!'), findsOneWidget);
  });
}
