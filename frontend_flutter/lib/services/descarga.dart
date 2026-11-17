/// Saves a text file where the person expects downloads: the Downloads folder
/// on Android and desktop, and the browser's download on the web.
library;

export 'descarga_io.dart' if (dart.library.js_interop) 'descarga_web.dart';
