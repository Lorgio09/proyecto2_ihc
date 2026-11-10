import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_resultado.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
// "Clásico de la facultad" was played 3 hours ago; its teams are accepted and
// the rival captain is jugador2 (Segundo Jugador).
const _partido = 'Clásico de la facultad';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets(
    'Resultado, disputa, corrección y confirmación entre organizador y capitán',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 1. The organizer registers the score: it waits for the captain.
      await entrar(tester, organizador);
      await abrirResultadoComoOrganizador(tester, _partido);
      await registrarMarcador(tester, 3, 2);
      expect(
        find.text('Marcador esperando la validación del capitán'),
        findsOneWidget,
      );
      expect(
        find.text('Todavía no hay un resultado definitivo'),
        findsOneWidget,
      );
      // The organizer cannot validate their own score.
      expect(find.byKey(const Key('boton-confirmar-resultado')), findsNothing);
      await verHistorial(tester);
      expect(
        find.text('Versión 1: 3 - 2 · Esperando validación'),
        findsOneWidget,
      );
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 2. The rival captain disputes it with a reason.
      await entrar(tester, capitan);
      await abrirResultadoComoJugador(tester, _partido);
      await disputar(tester, 'El tercer gol fue en fuera de juego');
      expect(
        find.text('Marcador disputado. El organizador debe corregirlo'),
        findsOneWidget,
      );
      expect(
        find.text('Todavía no hay un resultado definitivo'),
        findsOneWidget,
      );
      await verHistorial(tester);
      expect(find.text('Versión 1: 3 - 2 · Disputado'), findsOneWidget);
      expect(
        find.text('Motivo: El tercer gol fue en fuera de juego'),
        findsOneWidget,
      );
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 3. The organizer corrects it: the correction needs a new validation.
      await entrar(tester, organizador);
      await abrirResultadoComoOrganizador(tester, _partido);
      expect(find.text('Corregir el marcador'), findsOneWidget);
      await registrarMarcador(tester, 2, 2);
      expect(
        find.text('Marcador esperando la validación del capitán'),
        findsOneWidget,
      );
      expect(
        find.text('Todavía no hay un resultado definitivo'),
        findsOneWidget,
      );
      await verHistorial(tester);
      expect(
        find.text('Versión 2: 2 - 2 · Esperando validación'),
        findsOneWidget,
      );
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 4. The captain confirms: now, and only now, the result is definitive.
      await entrar(tester, capitan);
      await abrirResultadoComoJugador(tester, _partido);
      await tocar(tester, find.byKey(const Key('boton-confirmar-resultado')));
      await esperar(tester, find.text('Equipo A 2 - 2 Equipo B'));
      expect(find.text('Equipo A 2 - 2 Equipo B'), findsOneWidget);
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 5. Reload: a fresh app start and another player see the same data,
      //    with the whole history kept.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await entrar(tester, jugadorEquipoA);
      await abrirResultadoComoJugador(tester, _partido);
      expect(find.text('Equipo A 2 - 2 Equipo B'), findsOneWidget);
      expect(find.text('Resultado confirmado'), findsOneWidget);
      await verHistorial(tester);
      expect(find.text('Versión 2: 2 - 2 · Confirmado'), findsOneWidget);
      expect(find.text('Versión 1: 3 - 2 · Disputado'), findsOneWidget);
      expect(
        find.text('Motivo: El tercer gol fue en fuera de juego'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('boton-registrar-marcador')), findsNothing);
      expect(find.byKey(const Key('boton-confirmar-resultado')), findsNothing);
    },
  );
}
