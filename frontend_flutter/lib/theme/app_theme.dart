import 'package:flutter/material.dart';

import 'button_theme.dart';
import 'input_theme.dart';
import 'tokens.dart';

// The brand palette lives in tokens.dart only: every screen takes its colors
// from this scheme, so no Flutter default (purple) shows up anywhere.
final _esquema =
    ColorScheme.fromSeed(
      seedColor: UniColores.primario,
      brightness: Brightness.light,
    ).copyWith(
      primary: UniColores.primario,
      onPrimary: UniColores.sobreColor,
      secondary: UniColores.textoSecundario,
      onSecondary: UniColores.sobreColor,
      error: UniColores.error,
      onError: UniColores.sobreColor,
      surface: UniColores.superficie,
      onSurface: UniColores.texto,
      outlineVariant: UniColores.borde,
    );

final temaPrincipal = ThemeData(
  colorScheme: _esquema,
  scaffoldBackgroundColor: UniColores.fondo,
  appBarTheme: const AppBarTheme(
    backgroundColor: UniColores.superficie,
    foregroundColor: UniColores.texto,
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: false,
  ),
  textTheme: TextTheme(
    headlineMedium: UniTexto.titular.copyWith(color: UniColores.texto),
    // Also the AppBar and dialog titles.
    titleLarge: UniTexto.titulo.copyWith(color: UniColores.texto),
    titleMedium: UniTexto.subtitulo.copyWith(color: UniColores.texto),
    bodyLarge: UniTexto.cuerpo.copyWith(color: UniColores.texto),
    bodyMedium: UniTexto.cuerpoChico.copyWith(color: UniColores.texto),
    bodySmall: UniTexto.detalle.copyWith(color: UniColores.textoSecundario),
    labelLarge: UniTexto.boton,
  ),
  cardTheme: CardThemeData(
    color: UniColores.superficie,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(UniRadio.tarjeta),
      side: const BorderSide(color: UniColores.borde),
    ),
  ),
  dividerTheme: const DividerThemeData(color: UniColores.borde),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: UniColores.primario,
    foregroundColor: UniColores.sobreColor,
    elevation: 2,
  ),
  // Dark notice with white text: the old orange one reached only 2.6:1.
  snackBarTheme: SnackBarThemeData(
    backgroundColor: UniColores.aviso,
    contentTextStyle: UniTexto.cuerpoChico.copyWith(
      color: UniColores.sobreColor,
    ),
    actionTextColor: UniColores.primarioClaro,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: UniColores.primario,
    linearTrackColor: UniColores.pista,
  ),
  inputDecorationTheme: inputTheme,
  elevatedButtonTheme: elevatedButtonTheme,
);
