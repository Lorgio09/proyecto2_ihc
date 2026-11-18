// The E2E tests are written for a phone. On a desktop (Linux in GitHub
// Actions) the window is wide and short, so dialogs and lists lay out
// differently. There the app is drawn with the size of the Pixel 5 used on
// the emulator, so every test sees the same screen in both places.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Call once at the top of each test file's main(), instead of
/// IntegrationTestWidgetsFlutterBinding.ensureInitialized().
void iniciarComoTelefono() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;

  setUp(() {
    final vista = binding.platformDispatcher.views.first;
    // Pixel 5: 1080 x 2340 px at 2.625 px per point (411 x 891 points).
    vista.physicalSize = const Size(1080, 2340);
    vista.devicePixelRatio = 2.625;
  });
  tearDown(() => binding.platformDispatcher.views.first.reset());
}
