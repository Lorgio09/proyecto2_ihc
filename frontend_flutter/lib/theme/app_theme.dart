import 'package:flutter/material.dart';

import '../consts/color.dart';
import 'button_theme.dart';
import 'input_theme.dart';

// The brand palette lives here only: every screen takes its colors from this
// scheme, so no Flutter default (purple) shows up anywhere.
final _esquema = ColorScheme.fromSeed(
  seedColor: CoralAccesible,
  brightness: Brightness.light,
).copyWith(
  primary: CoralAccesible,
  onPrimary: white,
  secondary: Blueslate,
  onSecondary: white,
  surface: white,
  onSurface: Jetblack,
);

final temaPrincipal = ThemeData(
  colorScheme: _esquema,
  scaffoldBackgroundColor: const Color.fromRGBO(250, 248, 246, 1),
  appBarTheme: const AppBarTheme(
    backgroundColor: white,
    foregroundColor: Jetblack,
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Jetblack),
    // Also the AppBar titles.
    titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Jetblack),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Jetblack),
  ),
  cardTheme: CardThemeData(
    color: white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color.fromRGBO(226, 222, 218, 1)),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: CoralAccesible,
    foregroundColor: white,
    elevation: 2,
  ),
  inputDecorationTheme: inputTheme,
  elevatedButtonTheme: elevatedButtonTheme,
);
