import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/views/partido_view/formulario_partido.dart';

Partido crearPartido({required String estado, String deporte = 'futbol'}) {
  return Partido(
    id: 1,
    nombre: 'Partido de prueba',
    deporte: deporte,
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
  String deporte = 'futbol',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FormularioPartido(
          partido: crearPartido(estado: estado, deporte: deporte),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('todas las etiquetas van sobre su caja, también Deporte', (
    tester,
  ) async {
    await mostrarFormulario(tester, estado: 'cupos abiertos');

    final etiqueta = tester.getRect(find.text('Deporte'));
    final caja = tester.getRect(find.byType(DropdownButtonFormField<String>));

    // Deporte used the floating label that sits on the border of the box,
    // unlike every other field, which puts its label above it.
    expect(etiqueta.bottom, lessThanOrEqualTo(caja.top));
  });

  testWidgets('deja espacio entre un campo y la etiqueta del siguiente', (
    tester,
  ) async {
    await mostrarFormulario(tester, estado: 'cupos abiertos');

    final texto = find.byType(TextFormField);
    final nombre = tester.getRect(texto.at(0));
    final ubicacion = tester.getRect(texto.at(1));
    final cantidad = tester.getRect(texto.at(2));
    final tiempo = tester.getRect(texto.at(3));
    final deporte = tester.getRect(
      find.byType(DropdownButtonFormField<String>),
    );

    double hueco(Rect campo, String siguiente) =>
        tester.getRect(find.text(siguiente)).top - campo.bottom;

    expect(hueco(nombre, 'Deporte'), greaterThanOrEqualTo(12));
    expect(hueco(deporte, 'Ubicación'), greaterThanOrEqualTo(12));
    expect(hueco(ubicacion, 'Cantidad de jugadores'), greaterThanOrEqualTo(12));
    expect(hueco(cantidad, 'Tiempo en minutos'), greaterThanOrEqualTo(12));
    expect(hueco(tiempo, 'Estado'), greaterThanOrEqualTo(12));
  });

  testWidgets('muestra el deporte guardado del partido', (tester) async {
    await mostrarFormulario(
      tester,
      estado: 'cupos abiertos',
      deporte: 'basquet',
    );

    expect(find.text('Básquet'), findsOneWidget);
  });

  testWidgets('bloquea cantidad de jugadores cuando el equipo está completo', (
    tester,
  ) async {
    await mostrarFormulario(tester, estado: 'equipo completo');

    final campos = tester.widgetList<EditableText>(find.byType(EditableText));
    final campoCantidad = campos.elementAt(2);

    expect(campoCantidad.readOnly, isTrue);
    expect(
      find.text('No se puede modificar porque el equipo ya está completo'),
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

  testWidgets('muestra error si se guarda sin fecha', (tester) async {
    await mostrarFormulario(tester, estado: 'cupos abiertos');

    await tester.tap(find.byKey(const Key('boton-guardar-partido')));
    await tester.pump();

    expect(find.text('La fecha es obligatoria'), findsOneWidget);
  });
}
