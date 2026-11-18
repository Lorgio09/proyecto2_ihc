// Las pruebas E2E están escritas para un teléfono. En escritorio (Linux en
// GitHub Actions) la ventana es ancha y baja, así que los diálogos y las listas
// se acomodan distinto. Ahí la app se dibuja con el tamaño del Pixel 5 que se
// usa en el emulador, para que cada prueba vea la misma pantalla en ambos
// lugares.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Llamar una vez al inicio del main() de cada archivo de prueba, en lugar de
/// IntegrationTestWidgetsFlutterBinding.ensureInitialized().
void iniciarComoTelefono() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;

  setUp(() {
    final vista = binding.platformDispatcher.views.first;
    // Pixel 5: 1080 x 2340 px a 2.625 px por punto (411 x 891 puntos).
    vista.physicalSize = const Size(1080, 2340);
    vista.devicePixelRatio = 2.625;
  });
  tearDown(() => binding.platformDispatcher.views.first.reset());
}
