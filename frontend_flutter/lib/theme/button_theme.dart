import 'package:flutter/material.dart';

import 'tokens.dart';

final elevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: UniColores.primario,
    foregroundColor: UniColores.sobreColor,
    // Deshabilitado sigue legible: 5.6:1 en lugar del gris por defecto (2.0:1).
    disabledBackgroundColor: UniColores.deshabilitado,
    disabledForegroundColor: UniColores.textoSecundario,
  ),
);

// Los mismos colores que el Botón de Figma: el gris de deshabilitado que trae
// Material por defecto no es un token.
final filledButtonTheme = FilledButtonThemeData(
  style: FilledButton.styleFrom(
    backgroundColor: UniColores.primario,
    foregroundColor: UniColores.sobreColor,
    disabledBackgroundColor: UniColores.deshabilitado,
    disabledForegroundColor: UniColores.textoSecundario,
  ),
);
