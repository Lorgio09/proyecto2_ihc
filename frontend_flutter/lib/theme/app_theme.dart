import 'package:flutter/material.dart';

import 'button_theme.dart';
import 'input_theme.dart';
import 'tokens.dart';

// La paleta de la marca vive solo en tokens.dart: cada pantalla toma sus
// colores de este esquema, así no aparece en ningún lado un color por defecto
// de Flutter (morado).
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
    // También los títulos de la AppBar y de los diálogos.
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
  // Diálogos blancos con el título texto/titulo, como en Figma. Sin esto,
  // Material 3 los tiñe de rosa a partir del color semilla, que no es un token.
  dialogTheme: DialogThemeData(
    backgroundColor: UniColores.superficie,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: UniTexto.titulo.copyWith(color: UniColores.texto),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(UniRadio.tarjeta),
    ),
  ),
  dividerTheme: const DividerThemeData(color: UniColores.borde),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: UniColores.primario,
    foregroundColor: UniColores.sobreColor,
    elevation: 2,
  ),
  // Aviso oscuro con texto blanco: el naranja anterior llegaba solo a 2.6:1.
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
  filledButtonTheme: filledButtonTheme,
);
