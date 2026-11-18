import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/views/partido_view/reprogramar_partido.dart';

Partido _partido(DateTime? fecha) => Partido.fromJson({
  'id': 1,
  'nombre': 'Fulbito',
  'cantidad_jugadores': 10,
  'ubicacion': 'Cancha central',
  'fecha': fecha?.toUtc().toIso8601String(),
  'estado': 'cupos abiertos',
});

/// Abre el diálogo sobre un botón y guarda lo que devuelve.
class _Abridor {
  DatosReprogramacion? resultado;
  bool cerrado = false;
  final fallos = <String>[];

  Future<void> abrir(WidgetTester tester, Partido partido) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await showDialog<DatosReprogramacion>(
                context: context,
                builder: (_) => ReprogramarPartidoDialog(
                  partido: partido,
                  alFallar: fallos.add,
                ),
              );
              cerrado = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }
}

Future<void> _reprogramar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirmar-reprogramar-partido')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin cambios ni motivo no deja reprogramar y dice por qué', (
    tester,
  ) async {
    final abridor = _Abridor();
    await abridor.abrir(tester, _partido(null));
    expect(find.text('Fecha actual: Sin fecha'), findsOneWidget);
    expect(find.text('Nueva fecha: sin cambios'), findsOneWidget);

    await _reprogramar(tester);
    expect(find.text('Cambia la fecha, la hora o el lugar'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-ubicacion-reprogramacion')),
      'Cancha norte',
    );
    await _reprogramar(tester);
    expect(find.text('Escribe el motivo del cambio'), findsOneWidget);
    expect(abridor.fallos, ['SIN_CAMBIOS', 'MOTIVO_OBLIGATORIO']);
    expect(abridor.cerrado, isFalse);
  });

  testWidgets('con un lugar nuevo y un motivo devuelve solo lo que cambió', (
    tester,
  ) async {
    final abridor = _Abridor();
    await abridor.abrir(tester, _partido(DateTime(2030, 1, 1, 10)));
    expect(find.text('Fecha actual: 01/01/2030 10:00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-ubicacion-reprogramacion')),
      '  Cancha norte  ',
    );
    await tester.enterText(
      find.byKey(const Key('campo-motivo-reprogramacion')),
      'La cancha está en mantenimiento',
    );
    await _reprogramar(tester);

    expect(abridor.resultado?.ubicacion, 'Cancha norte');
    expect(abridor.resultado?.fecha, isNull);
    expect(abridor.resultado?.motivo, 'La cancha está en mantenimiento');
  });

  testWidgets('elige una nueva fecha y hora con el calendario y el reloj', (
    tester,
  ) async {
    final abridor = _Abridor();
    await abridor.abrir(tester, _partido(DateTime(2030, 1, 1, 10)));

    await tester.tap(find.byKey(const Key('boton-elegir-nueva-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva fecha: 15/01/2030 10:00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-motivo-reprogramacion')),
      'Feriado',
    );
    await _reprogramar(tester);
    expect(abridor.resultado?.fecha, DateTime(2030, 1, 15, 10));
    expect(abridor.resultado?.ubicacion, isNull);
  });

  testWidgets('una fecha que ya pasó no se acepta', (tester) async {
    final abridor = _Abridor();
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    // Ayer a las 00:00: el calendario empieza hoy, así que la nueva fecha es
    // hoy a las 00:00, que ya pasó.
    await abridor.abrir(tester, _partido(DateTime(ayer.year, ayer.month, ayer.day)));

    await tester.tap(find.byKey(const Key('boton-elegir-nueva-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-motivo-reprogramacion')),
      'Cambio',
    );
    await _reprogramar(tester);

    expect(find.text('La nueva fecha debe ser futura'), findsOneWidget);
    expect(abridor.fallos, ['FECHA_NO_FUTURA']);
  });

  testWidgets('cancelar el calendario, el reloj o el diálogo no cambia nada', (
    tester,
  ) async {
    final abridor = _Abridor();
    await abridor.abrir(tester, _partido(DateTime(2030, 1, 1, 10)));

    await tester.tap(find.byKey(const Key('boton-elegir-nueva-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva fecha: sin cambios'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boton-elegir-nueva-fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva fecha: sin cambios'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(abridor.cerrado, isTrue);
    expect(abridor.resultado, isNull);
  });
}
