import 'package:flutter/material.dart';

import '../consts/color.dart';
import 'button_theme.dart';
import 'input_theme.dart';

final temaPrincipal = ThemeData(
  scaffoldBackgroundColor: white,
  appBarTheme: const AppBarTheme(
    backgroundColor: white,
    foregroundColor: Jetblack,
    elevation: 0,
  ),
  inputDecorationTheme: inputTheme,
  elevatedButtonTheme: elevatedButtonTheme,
);
