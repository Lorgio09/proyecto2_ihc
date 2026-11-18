// Tarea 10 · Mis datos y salida honesta, end to end on the real backend:
// download the data, a deletion blocked by UniSport's rule, and a complete
// deletion after which the account cannot sign in. Each step checks its
// analytics events (start, success and block), which carry no personal data.
//
// Requires the backend running with seed data (backend/seed.py --reset).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/partido.dart';

import 'helpers_analitica.dart';
import 'helpers_resultado.dart';
import 'pantalla.dart';

/// Where the app saves the download on each platform (see descarga_io.dart):
/// the shared Downloads folder on Android, ~/Downloads on Linux (CI).
String get _descargas => Platform.isAndroid
    ? '/storage/emulated/0/Download'
    : '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/Downloads';
const _aviso = 'Tus datos se guardaron en Descargas/';

Future<void> _abrirMiCuenta(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-mi-cuenta')));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await esperar(tester, find.byKey(const Key('boton-descargar-datos')));
  await tester.pumpAndSettle();
}

Future<void> _tocarEliminar(WidgetTester tester) async {
  final boton = find.byKey(const Key('boton-eliminar-cuenta'));
  await tester.scrollUntilVisible(
    boton,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// A new account that joined "Futsal nocturno", so leaving has consequences.
Future<String> _cuentaConPartido() async {
  final email = 'e2e-${DateTime.now().millisecondsSinceEpoch}@unisport.test';
  final auth = AuthService();
  await auth.registro('Salida E2E', email, password, null);
  final partidos = PartidoService();
  final futsal = (await partidos.listarExplorar(busqueda: 'Futsal nocturno'))
      .first;
  await partidos.unirse(futsal.id);
  await auth.logout();
  return email;
}

void main() {
  iniciarComoTelefono();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets('El organizador intenta eliminar su cuenta y la regla lo frena', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await entrar(tester, organizador);
    final antes = await conteoEventos();

    await _abrirMiCuenta(tester);
    await _tocarEliminar(tester);

    // Why it is blocked and what to do, never the confirmation.
    expect(find.text('Todavía no puedes eliminar tu cuenta'), findsOneWidget);
    expect(find.textContaining('Amistoso del sábado'), findsOneWidget);
    expect(find.textContaining('Eliminar partido'), findsOneWidget);
    expect(find.text('Tu cuenta y tus datos siguen igual.'), findsOneWidget);
    expect(find.text('¿Eliminar tu cuenta?'), findsNothing);

    await tester.tap(find.byKey(const Key('cerrar-bloqueo')));
    await tester.pumpAndSettle();
    expect(find.text('Mi cuenta'), findsOneWidget);

    await expectEventos(antes, {
      'eliminacion_iniciada': 1,
      'tarea_fallida': 1,
      'cuenta_eliminada': 0,
    });
  });

  testWidgets(
    'Descarga sus datos, elimina la cuenta y ya no puede iniciar sesión',
    (tester) async {
      final email = await _cuentaConPartido();
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await entrar(tester, email);
      final antes = await conteoEventos();

      // 1. See and download the data.
      await _abrirMiCuenta(tester);
      expect(find.text(email), findsOneWidget);
      expect(find.text('Partidos en los que participas: 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('boton-descargar-datos')));
      final aviso = find.textContaining(_aviso);
      await esperar(tester, aviso);
      // Read back the very file the app says it saved.
      final nombre = (tester.widget<Text>(aviso).data ?? '').substring(
        _aviso.length,
      );
      final datos = jsonDecode(
        await File('$_descargas/$nombre').readAsString(),
      );
      expect(datos['cuenta']['email'], email);
      expect(datos['participaciones'][0]['partido'], 'Futsal nocturno');
      await limpiarAvisos(tester);

      // 2. The honest confirmation: consequences and two equal buttons.
      await _tocarEliminar(tester);
      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
      expect(
        find.textContaining('Sales de 1 partido que aún no se juega.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ya no podrás iniciar sesión con esta cuenta. No se puede deshacer.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('cancelar-eliminar-cuenta'))),
        tester.getSize(find.byKey(const Key('confirmar-eliminar-cuenta'))),
      );

      // 3. Delete: back to the login screen with a plain notice.
      await tester.tap(find.byKey(const Key('confirmar-eliminar-cuenta')));
      await esperar(tester, find.text('Tu cuenta fue eliminada'));
      expect(find.text('Tu cuenta fue eliminada'), findsOneWidget);
      expect(find.byKey(const Key('boton-ingresar')), findsOneWidget);
      await limpiarAvisos(tester);

      // 4. The account no longer signs in.
      await entrar(tester, email);
      expect(find.byKey(const Key('boton-ingresar')), findsOneWidget);
      expect(find.byKey(const Key('boton-mi-cuenta')), findsNothing);

      await expectEventos(antes, {
        'mis_datos_vistos': 1,
        'mis_datos_descargados': 1,
        'eliminacion_iniciada': 1,
        'cuenta_eliminada': 1,
        'tarea_fallida': 0,
      });
    },
  );
}
