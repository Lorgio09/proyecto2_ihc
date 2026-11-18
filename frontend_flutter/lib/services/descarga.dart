/// Guarda un archivo de texto donde la persona espera sus descargas: la carpeta
/// Descargas en Android y escritorio, y la descarga del navegador en la web.
library;

export 'descarga_io.dart' if (dart.library.js_interop) 'descarga_web.dart';
