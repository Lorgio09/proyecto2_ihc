import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_analitica.dart';
import 'helpers_resultado.dart';
import 'pantalla.dart';

// Requiere el backend corriendo con datos de seed (backend/seed.py --reset).
// "Clásico de la facultad" se jugó hace 3 horas; sus equipos están aceptados y
// el capitán rival es jugador2 (Segundo Jugador).
const _partido = 'Clásico de la facultad';

void main() {
  iniciarComoTelefono();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets(
    'Resultado, disputa, corrección y confirmación entre organizador y capitán',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final antes = await conteoEventos();

      // 1. El organizador registra el marcador: queda esperando al capitán.
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
      // El organizador no puede validar su propio marcador.
      expect(find.byKey(const Key('boton-confirmar-resultado')), findsNothing);
      await verHistorial(tester);
      expect(
        find.text('Versión 1: 3 - 2 · Esperando validación'),
        findsOneWidget,
      );
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 2. El capitán rival lo disputa indicando un motivo.
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

      // 3. El organizador lo corrige: la corrección necesita una nueva
      // validación.
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

      // 4. El capitán confirma: ahora, y solo ahora, el resultado es
      // definitivo.
      await entrar(tester, capitan);
      await abrirResultadoComoJugador(tester, _partido);
      await tocar(tester, find.byKey(const Key('boton-confirmar-resultado')));
      await esperar(tester, find.text('Equipo A 2 - 2 Equipo B'));
      expect(find.text('Equipo A 2 - 2 Equipo B'), findsOneWidget);
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 5. Recarga: un inicio nuevo de la app y otro jugador ven los mismos
      //    datos, con todo el historial conservado.
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

      // Dos marcadores registrados, uno disputado y uno confirmado.
      await expectEventos(antes, {
        'resultado_registrado': 2,
        'resultado_disputado': 1,
        'resultado_confirmado': 1,
      });
    },
  );
}
