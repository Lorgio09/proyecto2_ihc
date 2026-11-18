import 'package:flutter/material.dart';

/// UniSport design tokens: the single place where a color, type style,
/// spacing or radius is defined. Each name matches the Figma variable or
/// text style of the design system: `color/primario` in Figma is
/// `UniColores.primario` here, `texto/titulo` is `UniTexto.titulo`, and so on.
///
/// Screens and widgets never write a color or size literal; they use these
/// tokens or the theme built from them (lib/theme/app_theme.dart).

/// Figma: color/*
abstract final class UniColores {
  /// color/primario · buttons, links, brand icons. White on it: 4.96:1 (AA).
  static const primario = Color(0xFFC04A18);

  /// color/primario-claro · only the logo gradient, never under text.
  static const primarioClaro = Color(0xFFEF8354);

  /// color/primario-suave · background of icons in cards, home and empty states.
  static const primarioSuave = Color(0xFFF7E9E3);

  /// color/texto · titles and main text.
  static const texto = Color(0xFF2D3142);

  /// color/texto-secundario · descriptions, card details, supporting icons.
  static const textoSecundario = Color(0xFF4F5D75);

  /// color/sobre-color · text and icons on primario, error or aviso.
  static const sobreColor = Color(0xFFFFFFFF);

  /// color/superficie · cards, dialogs, app bar, fields.
  static const superficie = Color(0xFFFFFFFF);

  /// color/fondo · background of every screen.
  static const fondo = Color(0xFFFAF8F6);

  /// color/borde · card borders and dividers.
  static const borde = Color(0xFFE2DEDA);

  /// color/pista · empty part of the spots bar.
  static const pista = Color(0xFFECE7E2);

  /// color/exito · "Cupos abiertos" text and positive notices.
  static const exito = Color(0xFF166534);

  /// color/exito-suave · "Cupos abiertos" badge background.
  static const exitoSuave = Color(0xFFDCF1E2);

  /// color/neutro · "Equipo completo" text and other closed states.
  static const neutro = Color(0xFF374151);

  /// color/neutro-suave · "Equipo completo" badge background.
  static const neutroSuave = Color(0xFFE8EAEE);

  /// color/error · field errors and destructive buttons. On white: 6.5:1.
  static const error = Color(0xFFB3261E);

  /// color/aviso · snackbar background, with sobre-color text.
  static const aviso = Color(0xFF2D3142);

  /// color/deshabilitado · read-only fields and disabled buttons.
  static const deshabilitado = Color(0xFFEEEBE8);
}

/// Figma: texto/* (Roboto). Color comes from the theme, not from the style.
abstract final class UniTexto {
  /// texto/titular · 28/36 Bold
  static const titular = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
  );

  /// texto/titulo · 22/28 Bold
  static const titulo = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );

  /// texto/subtitulo · 16/24 SemiBold
  static const subtitulo = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// texto/cuerpo · 16/24 Regular
  static const cuerpo = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// texto/cuerpo-chico · 14/20 Regular
  static const cuerpoChico = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// texto/detalle · 12/16 Regular
  static const detalle = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// texto/boton · 14/20 Medium
  static const boton = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );
}

/// Figma: espacio/*
abstract final class UniEspacio {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

/// Figma: radio/*
abstract final class UniRadio {
  /// radio/campo · text fields
  static const double campo = 8;

  /// radio/icono · icon tiles
  static const double icono = 12;

  /// radio/tarjeta · cards and dialogs
  static const double tarjeta = 16;

  /// radio/pildora · buttons, badges and bars (fully rounded)
  static const double pildora = 999;
}
