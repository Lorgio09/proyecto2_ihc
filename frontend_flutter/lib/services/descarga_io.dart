import 'dart:io';

import 'package:flutter/foundation.dart';

/// Android and desktop: writes [contenido] in the Downloads folder and
/// returns the file's path.
Future<String> guardarArchivo(String nombre, String contenido) async {
  final carpeta = carpetaDescargas();
  await carpeta.create(recursive: true);
  final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
  await archivo.writeAsString(contenido);
  return archivo.path;
}

/// Where downloads go. [android] and [entorno] default to the real device;
/// tests pass them to check every case.
@visibleForTesting
Directory carpetaDescargas({bool? android, Map<String, String>? entorno}) {
  // Android 11+ lets an app create its own files in the shared Downloads
  // folder without asking for any permission.
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
