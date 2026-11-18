// Pasos compartidos de las pruebas E2E de validación del resultado (cuentas de
// seed).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const password = 'Seed1234';
const organizador = 'organizador@unisport.test';
const jugadorEquipoA = 'jugador@unisport.test';
const capitan = 'jugador2@unisport.test';
const tercerJugador = 'jugador3@unisport.test';

/// Avanza frames hasta que aparece [finder]; un snackbar sigue visible tras
/// pumpAndSettle.
Future<void> esperar(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Un snackbar puede tapar el siguiente botón a tocar.
Future<void> limpiarAvisos(WidgetTester tester) async {
  final scaffolds = find.byType(Scaffold).evaluate();
  if (scaffolds.isEmpty) return;
  ScaffoldMessenger.of(scaffolds.last).clearSnackBars();
  await tester.pumpAndSettle();
}

Finder _listaVisible() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// Desplaza la lista visible hasta que [finder] queda en pantalla.
Future<void> mostrar(WidgetTester tester, Finder finder) async {
  await esperar(tester, find.byType(ListView));
  await tester.scrollUntilVisible(finder, 200, scrollable: _listaVisible());
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await limpiarAvisos(tester);
  await mostrar(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> entrar(WidgetTester tester, String email) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), email);
  await tester.enterText(campos.at(1), password);
  await tester.tap(find.byKey(const Key('boton-ingresar')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> cerrarSesion(WidgetTester tester) async {
  await limpiarAvisos(tester);
  await tester.tap(find.byTooltip('Cerrar sesión'));
  await tester.pumpAndSettle();
}

/// Desde la pantalla de resultado (o cualquiera abierta encima de Inicio) de
/// vuelta a Inicio.
Future<void> salirAlInicio(WidgetTester tester) async {
  await limpiarAvisos(tester);
  while (find.byTooltip('Cerrar sesión').evaluate().isEmpty) {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
}

Future<void> _abrirMisPartidos(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('boton-mis-partidos')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _esperarResultado(WidgetTester tester) async {
  await esperar(tester, find.byKey(const Key('estado-validacion')));
  await tester.pumpAndSettle();
}

/// Organizador: Mis partidos > Organizo > "Resultado del partido" del partido.
Future<void> abrirResultadoComoOrganizador(
  WidgetTester tester,
  String partido,
) async {
  await _abrirMisPartidos(tester);
  final tarjeta = find.widgetWithText(Card, partido);
  await mostrar(tester, tarjeta);
  // "Resultado del partido" está en el menú "⋮" de la tarjeta.
  final menu = find.descendant(
    of: tarjeta,
    matching: find.byTooltip('Más acciones'),
  );
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('boton-resultado-partido')));
  await _esperarResultado(tester);
}

/// Jugador: Mis partidos > Me uní > "Resultado" del partido.
Future<void> abrirResultadoComoJugador(
  WidgetTester tester,
  String partido,
) async {
  await _abrirMisPartidos(tester);
  await tester.tap(find.text('Me uní'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  final tarjeta = find.widgetWithText(Card, partido);
  await mostrar(tester, tarjeta);
  final boton = find.descendant(of: tarjeta, matching: find.text('Resultado'));
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await _esperarResultado(tester);
}

Future<void> registrarMarcador(
  WidgetTester tester,
  int golesA,
  int golesB,
) async {
  await mostrar(tester, find.byKey(const Key('campo-goles-a')));
  await tester.enterText(find.byKey(const Key('campo-goles-a')), '$golesA');
  await tester.enterText(find.byKey(const Key('campo-goles-b')), '$golesB');
  await tocar(tester, find.byKey(const Key('boton-registrar-marcador')));
  await esperar(
    tester,
    find.text('Marcador esperando la validación del capitán'),
  );
}

Future<void> disputar(WidgetTester tester, String motivo) async {
  await tocar(tester, find.byKey(const Key('boton-disputar-resultado')));
  await tester.enterText(find.byKey(const Key('campo-motivo-disputa')), motivo);
  await tester.tap(find.byKey(const Key('enviar-disputa')));
  await tester.pumpAndSettle();
  await esperar(
    tester,
    find.text('Marcador disputado. El organizador debe corregirlo'),
  );
}

/// Desplaza hasta el historial de marcadores, al final de la pantalla de
/// resultado.
Future<void> verHistorial(WidgetTester tester) async {
  await mostrar(tester, find.byKey(const Key('seccion-historial')));
}
