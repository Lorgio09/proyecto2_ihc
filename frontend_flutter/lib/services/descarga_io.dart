import 'dart:io';

/// Android and desktop: writes [contenido] in the Downloads folder and
/// returns the file's path.
Future<String> guardarArchivo(String nombre, String contenido) async {
  final carpeta = _carpetaDescargas();
  await carpeta.create(recursive: true);
  final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
  await archivo.writeAsString(contenido);
  return archivo.path;
}

Directory _carpetaDescargas() {
  // Android 11+ lets an app create its own files in the shared Downloads
  // folder without asking for any permission.
  if (Platform.isAndroid) return Directory('/storage/emulated/0/Download');
  final inicio =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (inicio != null) {
    return Directory('$inicio${Platform.pathSeparator}Downloads');
  }
  return Directory.systemTemp;
}
