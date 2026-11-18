import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/widgets/input.dart';

void main() {
  testWidgets('el campo se anuncia con su etiqueta y no con el ejemplo', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Input(
            etiqueta: 'Email',
            controlador: TextEditingController(),
            placeholder: 'correo@ejemplo.com',
          ),
        ),
      ),
    );

    final campo = tester.getSemantics(find.byType(EditableText));
    expect(campo.label, contains('Email'));
    expect(campo.flagsCollection.isTextField, isTrue);
    // La etiqueta visible no se lee una segunda vez como texto suelto: solo el
    // campo lleva "Email".
    expect(find.bySemanticsLabel(RegExp('Email')), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('la contraseña se anuncia como contraseña y el ojito aparte', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Input(
            etiqueta: 'Contraseña',
            controlador: TextEditingController(),
            placeholder: '••••••••',
            ocultarTexto: true,
          ),
        ),
      ),
    );

    final campo = tester.getSemantics(find.byType(EditableText));
    expect(campo.label, contains('Contraseña'));
    expect(campo.flagsCollection.isObscured, isTrue);
    // El ojo sigue siendo su propio botón, descrito por su tooltip.
    final ojo = tester.getSemantics(find.byType(IconButton));
    expect(ojo.tooltip, 'Mostrar contraseña');
    expect(ojo.flagsCollection.isButton, isTrue);
    semantica.dispose();
  });
}
