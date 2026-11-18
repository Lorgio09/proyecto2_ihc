import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../widgets/confirmacion.dart';

/// Salir de un partido, dicho con claridad: qué pasa con el cupo y, si es
/// tarde, que el organizador lo verá. Solo hechos, sin culpa.
/// Lo comparten Explorar partidos y Mis partidos > Me uní.
Future<bool> confirmarSalida(
  BuildContext context,
  Partido partido,
  int usuarioId,
) {
  final esTitular = partido.participantes.any((p) => p.id == usuarioId);
  return confirmarAccion(
    context,
    titulo: 'Salir de ${partido.nombre}',
    consecuencias: [
      if (partido.salidaSeriaTardia)
        'Faltan menos de 2 horas: quedará registrado como baja tardía y el '
            'organizador lo verá.',
      if (esTitular && partido.cantidadSuplentes > 0)
        'Tu lugar de titular pasa al primer suplente.'
      else
        'Tu lugar queda libre para otro jugador.',
      'Puedes volver a unirte mientras el partido no se juegue.',
    ],
    textoConfirmar: 'Salir del partido',
    keyConfirmar: const Key('confirmar-salir-partido'),
  );
}
