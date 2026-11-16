import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/widgets/input.dart';

Future<void> mostrarInput(
  WidgetTester tester, {
  bool ocultarTexto = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Input(
          etiqueta: 'Contraseña',
          controlador: TextEditingController(text: 'Seed1234'),
          ocultarTexto: ocultarTexto,
        ),
      ),
    ),
  );
}

bool textoOculto(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).obscureText;

void main() {
  testWidgets('un campo de contraseña arranca oculto y se puede mostrar', (
    tester,
  ) async {
    await mostrarInput(tester, ocultarTexto: true);
    expect(textoOculto(tester), isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    expect(textoOculto(tester), isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });

  testWidgets('el ojito vuelve a ocultar la contraseña', (tester) async {
    await mostrarInput(tester, ocultarTexto: true);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();

    expect(textoOculto(tester), isTrue);
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
  });

  testWidgets('el ojito tiene un área táctil de al menos 48 px', (
    tester,
  ) async {
    await mostrarInput(tester, ocultarTexto: true);

    final area = tester.getSize(find.byType(IconButton));

    expect(area.width, greaterThanOrEqualTo(48));
    expect(area.height, greaterThanOrEqualTo(48));
  });

  testWidgets('un campo de texto normal no muestra el ojito', (tester) async {
    await mostrarInput(tester);

    expect(textoOculto(tester), isFalse);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byTooltip('Mostrar contraseña'), findsNothing);
  });
}
