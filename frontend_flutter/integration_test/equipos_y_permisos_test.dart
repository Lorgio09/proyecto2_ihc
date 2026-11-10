import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_resultado.dart';

// Requires the backend running with seed data (backend/seed.py --reset).
// "Amistoso del sábado" is next week, with three players and no teams yet.
const _partido = 'Amistoso del sábado';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets(
    'Solo el capitán acepta los equipos y el marcador espera al final del partido',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // The organizer proposes the teams and the rival captain.
      await entrar(tester, organizador);
      await abrirResultadoComoOrganizador(tester, _partido);
      expect(
        find.text('El organizador todavía no propuso los equipos'),
        findsOneWidget,
      );
      await tocar(tester, find.byKey(const Key('equipo-b-Segundo Jugador')));
      await tocar(tester, find.byKey(const Key('equipo-b-Tercer Jugador')));
      await tocar(tester, find.byKey(const Key('capitan-Segundo Jugador')));
      await tocar(tester, find.byKey(const Key('boton-proponer-equipos')));
      await esperar(
        tester,
        find.text('Esperando que el capitán rival acepte los equipos'),
      );
      expect(
        find.text('Esperando que el capitán rival acepte los equipos'),
        findsOneWidget,
      );
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // A teammate of the captain can see the proposal but cannot accept it.
      await entrar(tester, tercerJugador);
      await abrirResultadoComoJugador(tester, _partido);
      expect(
        find.text('Esperando que el capitán rival acepte los equipos'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('boton-aceptar-equipos')), findsNothing);
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // The captain accepts before the match.
      await entrar(tester, capitan);
      await abrirResultadoComoJugador(tester, _partido);
      await tocar(tester, find.byKey(const Key('boton-aceptar-equipos')));
      const aceptados =
          'Equipos aceptados. El marcador se registra al terminar el partido';
      await esperar(tester, find.text(aceptados));
      expect(find.text(aceptados), findsOneWidget);
      expect(find.byKey(const Key('boton-aceptar-equipos')), findsNothing);
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // Reload: the acceptance persists, and the organizer still cannot
      // register a score because the match has not been played.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await entrar(tester, organizador);
      await abrirResultadoComoOrganizador(tester, _partido);
      expect(find.text(aceptados), findsOneWidget);
      expect(find.text('El capitán aceptó los equipos'), findsOneWidget);
      expect(find.byKey(const Key('boton-registrar-marcador')), findsNothing);
      expect(find.byKey(const Key('boton-proponer-equipos')), findsOneWidget);
    },
  );
}
