import 'package:flutter/material.dart';

import 'tokens.dart';

final elevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: UniColores.primario,
    foregroundColor: UniColores.sobreColor,
    // Disabled stays readable: 5.6:1 instead of the default grey (2.0:1).
    disabledBackgroundColor: UniColores.deshabilitado,
    disabledForegroundColor: UniColores.textoSecundario,
  ),
);
