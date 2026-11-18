import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/accesibilidad.dart';
import 'package:frontend_flutter/main.dart' as app;

void main() {
  testWidgets('en web la accesibilidad queda activa desde el arranque', (
    tester,
  ) async {
    expect(activarSemanticaEnWeb(esWeb: false), isNull);

    final handle = activarSemanticaEnWeb(esWeb: true);
    expect(handle, isNotNull);
    expect(SemanticsBinding.instance.semanticsEnabled, isTrue);
    handle!.dispose();
  });

  testWidgets('sin sesión guardada, la app arranca en el inicio de sesión', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    app.main();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boton-ingresar')), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'UniSport');
  });
}
