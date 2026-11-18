import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/services/auth_service.dart';

import 'helpers_analitica.dart';
import 'helpers_resultado.dart';
import 'pantalla.dart';

// Requiere el backend corriendo con datos de seed (backend/seed.py --reset).
// "Baja con tiempo" es en 2 días: jugador ocupa su único cupo y jugador2
// espera como suplente. "Baja de último momento" empieza en 90 minutos, así que
// salir de él es una baja tardía.
const _aTiempo = 'Baja con tiempo';
const _tardio = 'Baja de último momento';

Future<void> _abrirMisPartidos(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-mis-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// Jugador: Mis partidos > Me uní > "Salir del partido" en [partido].
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

  // Lo que la confirmación le dice al jugador antes de salir.
  final aviso = find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Text))
      .evaluate()
      .map((elemento) => (elemento.widget as Text).data ?? '')
      .join(' ');
  await tester.tap(find.byKey(const Key('confirmar-salir-partido')));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  return aviso;
}

/// Organizador: Mis partidos > Organizo > la tarjeta de [partido], con
/// participantes abiertos.
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
  iniciarComoTelefono();

  setUp(() async {
    await AuthService().logout();
  });

  testWidgets(
    'Una baja a tiempo sube al suplente y una baja tardía queda registrada',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final antes = await conteoEventos();

      // 1. Faltando 2 días, Jugador Demo sale: una confirmación normal.
      await entrar(tester, jugadorEquipoA);
      final avisoATiempo = await _salirDesdeMeUni(tester, _aTiempo);
      expect(avisoATiempo, contains('Puedes volver a unirte'));
      expect(avisoATiempo, isNot(contains('baja tardía')));
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 2. 90 minutos antes del inicio, Tercer Jugador recibe el aviso y sale.
      await entrar(tester, tercerJugador);
      final avisoTardio = await _salirDesdeMeUni(tester, _tardio);
      expect(avisoTardio, contains('baja tardía'));
      await salirAlInicio(tester);
      await cerrarSesion(tester);

      // 3. El organizador ve al suplente ascendido en el primer partido...
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

      // ...y la baja tardía en el segundo.
      await salirAlInicio(tester);
      tarjeta = await _tarjetaDelOrganizador(tester, _tardio);
      expect(_en(tarjeta, 'Bajas tardías: Tercer Jugador'), findsOneWidget);

      // Dos bajas iniciadas y dos registradas.
      await expectEventos(antes, {'baja_iniciada': 2, 'baja_registrada': 2});
    },
  );
}
