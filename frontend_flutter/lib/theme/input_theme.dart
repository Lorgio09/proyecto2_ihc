import 'package:flutter/material.dart';

import 'tokens.dart';

final inputTheme = InputDecorationTheme(
  filled: true,
  fillColor: UniColores.superficie,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(UniRadio.campo),
  ),
  errorStyle: UniTexto.detalle.copyWith(color: UniColores.error),
);
