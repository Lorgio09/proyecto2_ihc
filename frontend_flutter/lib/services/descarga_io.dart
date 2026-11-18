import 'dart:io';

import 'package:flutter/foundation.dart';

/// Android y escritorio: escribe [contenido] en la carpeta Descargas y
/// devuelve la ruta del archivo.
Future<String> guardarArchivo(String nombre, String contenido) async {
  final carpeta = carpetaDescargas();
  await carpeta.create(recursive: true);
  final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
  await archivo.writeAsString(contenido);
  return archivo.path;
}

/// Dónde van las descargas. [android] y [entorno] usan por defecto el
/// dispositivo real; las pruebas los pasan para revisar cada caso.
@visibleForTesting
Directory carpetaDescargas({bool? android, Map<String, String>? entorno}) {
  // Android 11+ deja que una app cree sus propios archivos en la carpeta
  // compartida Descargas sin pedir ningún permiso.
  if (android ?? Platform.isAndroid) {
    return Directory('/storage/emulated/0/Download');
  }
  final variables = entorno ?? Platform.environment;
  final inicio = variables['HOME'] ?? variables['USERPROFILE'];
  if (inicio != null) {
    return Directory('$inicio${Platform.pathSeparator}Downloads');
  }
  return Directory.systemTemp;
}
