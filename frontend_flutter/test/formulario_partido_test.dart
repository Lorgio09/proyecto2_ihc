import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/views/partido_view/formulario_partido.dart';

Partido crearPartido({required String estado}) {
  return Partido(
    id: 1,
    nombre: 'Partido de prueba',
    cantidadJugadores: 10,
    ubicacion: 'Cancha de prueba',
    tiempoMin: '90',
    fecha: null,
    estado: estado,
  );
}

Future<void> mostrarFormulario(
  WidgetTester tester, {
  required String estado,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FormularioPartido(partido: crearPartido(estado: estado)),
      ),
    ),
  );
}

void main() {
  testWidgets('bloquea cantidad de jugadores cuando el equipo está completo', (
    tester,
  ) async {
    await mostrarFormulario(tester, estado: 'equipo completo');

    final campos = tester.widgetList<EditableText>(find.byType(EditableText));
    final campoCantidad = campos.elementAt(2);

    expect(campoCantidad.readOnly, isTrue);
    expect(
      find.text('no se puede modificar porque el equipo ya esta completo'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, '-')).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, '+')).onPressed,
      isNull,
    );
  });

  testWidgets(
    'permite modificar cantidad de jugadores cuando hay cupos abiertos',
    (tester) async {
      await mostrarFormulario(tester, estado: 'Cupos abiertos');

      final campos = tester.widgetList<EditableText>(find.byType(EditableText));
      final campoCantidad = campos.elementAt(2);

      expect(campoCantidad.readOnly, isFalse);
      expect(
        find.text('No se puede editar porque el equipo está completo.'),
        findsNothing,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '-'))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '+'))
            .onPressed,
        isNotNull,
      );
    },
  );
}
