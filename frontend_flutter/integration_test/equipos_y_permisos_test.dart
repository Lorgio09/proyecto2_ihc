import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_resultado.dart';
import 'pantalla.dart';

// Requiere el backend corriendo con datos de seed (backend/seed.py --reset).
// "Amistoso del sábado" es la próxima semana, con tres jugadores y aún sin
// equipos.
const _partido = 'Amistoso del sábado';

void main() {
  iniciarComoTelefono();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets(
    'Solo el capitán acepta los equipos y el marcador espera al final del partido',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // El organizador propone los equipos y el capitán rival.
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

      // Un compañero del capitán puede ver la propuesta pero no aceptarla.
      await entrar(tester, tercerJugador);
      await abrirResultadoComoJugador(tester, _partido);
      expect(
        find.text('Esperando que el capitán rival acepte los equipos'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('boton-aceptar-equipos')), findsNothing);
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // El capitán acepta antes del partido.
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

      // Recarga: la aceptación se mantiene, y el organizador aún no puede
      // registrar un marcador porque el partido no se ha jugado.
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
