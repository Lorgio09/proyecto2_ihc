import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

/// Flutter web dibuja la app en un canvas y arma el árbol de accesibilidad solo
/// cuando alguien lo activa. Si se activa desde el inicio, los lectores de
/// pantalla (y auditorías como Lighthouse) ven los botones, campos y textos
/// reales.
///
/// Devuelve el objeto que lo mantiene activo, o null si no corre en la web.
SemanticsHandle? activarSemanticaEnWeb({bool esWeb = kIsWeb}) {
  if (!esWeb) return null;
  return SemanticsBinding.instance.ensureSemantics();
}
