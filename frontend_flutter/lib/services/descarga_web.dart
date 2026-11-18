import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: entrega [contenido] al navegador como una descarga llamada [nombre]. El
/// navegador la guarda en su carpeta de descargas, sin pedir permisos.
Future<String> guardarArchivo(String nombre, String contenido) async {
  final archivo = web.Blob(
    [contenido.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final enlace = web.URL.createObjectURL(archivo);
  final ancla = web.HTMLAnchorElement()
    ..href = enlace
    ..download = nombre
    ..style.display = 'none';
  web.document.body?.append(ancla);
  ancla.click();
  ancla.remove();
  web.URL.revokeObjectURL(enlace);
  return nombre;
}
