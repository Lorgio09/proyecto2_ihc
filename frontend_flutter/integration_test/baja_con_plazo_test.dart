import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_resultado.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
// "Baja con tiempo" is in 2 days: jugador holds its only spot and jugador2
// waits as substitute. "Baja de último momento" starts in 90 minutes, so
// leaving it is a late withdrawal.
const _aTiempo = 'Baja con tiempo';
const _tardio = 'Baja de último momento';

Future<void> _abrirMisPartidos(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-mis-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// Player: Mis partidos > Me uní > "Salir del partido" on [partido].
Future<String> _salirDesdeMeUni(WidgetTester tester, String partido) async {
  await _abrirMisPartidos(tester);
  await tester.tap(find.text('Me uní'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  final tarjeta = find.widgetWithText(Card, partido);
  await mostrar(tester, tarjeta);
  final boton = find.descendant(
    of: tarjeta,
    matching: find.text('Salir del partido'),
  );
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();

  // What the confirmation tells the player before leaving.
  final aviso = find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Text))
      .evaluate()
      .map((elemento) => (elemento.widget as Text).data ?? '')
      .join(' ');
  await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  return aviso;
}

/// Organizer: Mis partidos > Organizo > the card of [partido], participants open.
Future<Finder> _tarjetaDelOrganizador(
  WidgetTester tester,
  String partido,
) async {
  await _abrirMisPartidos(tester);
  final tarjeta = find.widgetWithText(Card, partido);
  await mostrar(tester, tarjeta);
  final ver = find.descendant(
    of: tarjeta,
    matching: find.text('Ver participantes'),
  );
  if (ver.evaluate().isNotEmpty) {
    await tester.ensureVisible(ver);
    await tester.pumpAndSettle();
    await tester.tap(ver);
    await tester.pumpAndSettle();
  }
  return tarjeta;
}

Finder _en(Finder tarjeta, String texto) =>
    find.descendant(of: tarjeta, matching: find.text(texto));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets(
    'Una baja a tiempo sube al suplente y una baja tardía queda registrada',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 1. With 2 days to go, Jugador Demo leaves: a normal confirmation.
      await entrar(tester, jugadorEquipoA);
      final avisoATiempo = await _salirDesdeMeUni(tester, _aTiempo);
      expect(avisoATiempo, contains('¿Quieres salir de este partido?'));
      expect(avisoATiempo, isNot(contains('baja tardía')));
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 2. 90 minutes before kick-off, Tercer Jugador is warned and leaves.
      await entrar(tester, tercerJugador);
      final avisoTardio = await _salirDesdeMeUni(tester, _tardio);
      expect(avisoTardio, contains('baja tardía'));
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 3. The organizer sees the substitute promoted on the first match...
      await entrar(tester, organizador);
      var tarjeta = await _tarjetaDelOrganizador(tester, _aTiempo);
      expect(_en(tarjeta, 'Cupos: 1/1'), findsOneWidget);
      expect(_en(tarjeta, 'Segundo Jugador'), findsOneWidget);
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.textContaining('Bajas tardías'),
        ),
        findsNothing,
      );

      // ...and the late withdrawal on the second one.
      await salirAlInicio(tester);
      tarjeta = await _tarjetaDelOrganizador(tester, _tardio);
      expect(_en(tarjeta, 'Bajas tardías: Tercer Jugador'), findsOneWidget);
    },
  );
}
