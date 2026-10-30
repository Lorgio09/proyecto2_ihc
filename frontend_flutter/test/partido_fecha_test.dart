import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';

void main() {
  test('Al crear un partido la fecha local se envía en UTC con zona', () {
    final local = DateTime(2026, 10, 30, 0, 0);
    final json = PartidoCreateRequest(
      nombre: 'Partido',
      cantidadJugadores: 10,
      ubicacion: 'Cancha',
      fecha: local,
      deporte: 'futbol',
    ).toJson();

    final enviada = json['fecha'] as String;
    expect(enviada.endsWith('Z'), isTrue);
    expect(DateTime.parse(enviada).isAtSameMomentAs(local), isTrue);
  });

  test('Al leer un partido la fecha UTC se muestra en hora local', () {
    final partido = Partido.fromJson({
      'id': 1,
      'nombre': 'Partido',
      'cantidad_jugadores': 10,
      'ubicacion': 'Cancha',
      'tiempo_min': null,
      'fecha': '2026-10-30T04:00:00+00:00',
      'estado': 'cupos abiertos',
    });

    expect(partido.fecha!.isUtc, isFalse);
    expect(
      partido.fecha!.isAtSameMomentAs(DateTime.utc(2026, 10, 30, 4)),
      isTrue,
    );
  });
}
