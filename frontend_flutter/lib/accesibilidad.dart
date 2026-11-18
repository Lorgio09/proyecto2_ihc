import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

/// Flutter web draws the app on a canvas and builds the accessibility tree
/// only after someone turns it on. Turned on from the start, screen readers
/// (and audits like Lighthouse) see the real buttons, fields and texts.
///
/// Returns the handle that keeps it on, or null when not running on the web.
SemanticsHandle? activarSemanticaEnWeb({bool esWeb = kIsWeb}) {
  if (!esWeb) return null;
  return SemanticsBinding.instance.ensureSemantics();
}
