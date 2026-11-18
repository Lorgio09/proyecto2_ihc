import 'package:flutter/material.dart';

/// Tokens de diseño de UniSport: el único lugar donde se define un color,
/// estilo de texto, espaciado o radio. Cada nombre coincide con la variable o
/// estilo de texto del sistema de diseño en Figma: `color/primario` en Figma es
/// `UniColores.primario` aquí, `texto/titulo` es `UniTexto.titulo`, y así.
///
/// Las pantallas y widgets nunca escriben un color o tamaño literal; usan estos
/// tokens o el tema construido con ellos (lib/theme/app_theme.dart).

/// Figma: color/*
abstract final class UniColores {
  /// color/primario · botones, enlaces, íconos de marca. Blanco encima: 4.96:1
  /// (AA).
  static const primario = Color(0xFFC04A18);

  /// color/primario-claro · solo el degradado del logo, nunca debajo de texto.
  static const primarioClaro = Color(0xFFEF8354);

  /// color/primario-suave · fondo de íconos en tarjetas, inicio y estados
  /// vacíos.
  static const primarioSuave = Color(0xFFF7E9E3);

  /// color/texto · títulos y texto principal.
  static const texto = Color(0xFF2D3142);

  /// color/texto-secundario · descripciones, detalles de tarjeta, íconos de
  /// apoyo.
  static const textoSecundario = Color(0xFF4F5D75);

  /// color/sobre-color · texto e íconos sobre primario, error o aviso.
  static const sobreColor = Color(0xFFFFFFFF);

  /// color/superficie · tarjetas, diálogos, barra superior, campos.
  static const superficie = Color(0xFFFFFFFF);

  /// color/fondo · fondo de todas las pantallas.
  static const fondo = Color(0xFFFAF8F6);

  /// color/borde · bordes de tarjeta y divisores.
  static const borde = Color(0xFFE2DEDA);

  /// color/pista · parte vacía de la barra de cupos.
  static const pista = Color(0xFFECE7E2);

  /// color/exito · texto "Cupos abiertos" y avisos positivos.
  static const exito = Color(0xFF166534);

  /// color/exito-suave · fondo de la etiqueta "Cupos abiertos".
  static const exitoSuave = Color(0xFFDCF1E2);

  /// color/neutro · texto "Equipo completo" y otros estados cerrados.
  static const neutro = Color(0xFF374151);

  /// color/neutro-suave · fondo de la etiqueta "Equipo completo".
  static const neutroSuave = Color(0xFFE8EAEE);

  /// color/error · errores de campos y botones destructivos. Sobre blanco:
  /// 6.5:1.
  static const error = Color(0xFFB3261E);

  /// color/aviso · fondo del snackbar, con texto sobre-color.
  static const aviso = Color(0xFF2D3142);

  /// color/deshabilitado · campos de solo lectura y botones deshabilitados.
  static const deshabilitado = Color(0xFFEEEBE8);
}

/// Figma: texto/* (Roboto). El color lo pone el tema, no el estilo.
abstract final class UniTexto {
  /// texto/titular · 28/36 negrita
  static const titular = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
  );

  /// texto/titulo · 22/28 negrita
  static const titulo = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );

  /// texto/subtitulo · 16/24 seminegrita
  static const subtitulo = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// texto/cuerpo · 16/24 regular
  static const cuerpo = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// texto/cuerpo-chico · 14/20 regular
  static const cuerpoChico = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// texto/detalle · 12/16 regular
  static const detalle = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// texto/boton · 14/20 medio
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
  /// radio/campo · campos de texto
  static const double campo = 8;

  /// radio/icono · recuadros de íconos
  static const double icono = 12;

  /// radio/tarjeta · tarjetas y diálogos
  static const double tarjeta = 16;

  /// radio/pildora · botones, etiquetas y barras (totalmente redondeados)
  static const double pildora = 999;
}
