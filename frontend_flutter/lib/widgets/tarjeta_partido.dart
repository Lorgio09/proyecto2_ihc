import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../models/partido.dart';

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "Vie 20 nov · 18:00", como la gente dice en voz alta la fecha de un partido.
String fechaLegible(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha';
  final hora =
      '${fecha.hour.toString().padLeft(2, '0')}:'
      '${fecha.minute.toString().padLeft(2, '0')}';
  return '${_dias[fecha.weekday - 1]} ${fecha.day} '
      '${_meses[fecha.month - 1]} · $hora';
}

IconData iconoDeporte(String deporte) {
  switch (deporte) {
    case 'basquet':
      return Icons.sports_basketball;
    case 'voley':
      return Icons.sports_volleyball;
    default:
      return Icons.sports_soccer;
  }
}

/// Un partido, mostrado igual en Mis partidos, Me uní y Explorar: deporte y
/// estado de un vistazo, los datos clave con íconos, qué tan lleno está, avisos
/// y las acciones de quien lo mira.
class TarjetaPartido extends StatelessWidget {
  const TarjetaPartido({
    super.key,
    required this.partido,
    this.organizador,
    this.avisos = const [],
    this.participantesAbiertos = false,
    this.alAlternarParticipantes,
    this.mostrarNombresDeSuplentes = false,
    this.menu,
    this.acciones,
  });

  final Partido partido;

  /// Se muestra bajo el título cuando quien mira no es el organizador.
  final String? organizador;

  /// Avisos cortos (reprogramación, puesto de suplente, bajas tardías...).
  final List<Widget> avisos;
  final bool participantesAbiertos;
  final VoidCallback? alAlternarParticipantes;
  final bool mostrarNombresDeSuplentes;

  /// Acciones secundarias, en la esquina superior derecha (p. ej. un menú "⋮").
  final Widget? menu;

  /// Acciones principales, abajo.
  final Widget? acciones;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final subtitulo = organizador == null
        ? partido.deporteTexto
        : '${partido.deporteTexto} · Organiza $organizador';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconoDeporte(deporte: partido.deporte),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partido.nombre, style: textos.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: textos.bodySmall?.copyWith(
                          color: UniColores.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _InsigniaEstado(partido: partido),
                    ],
                  ),
                ),
                ?menu,
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Dato(icono: Icons.event, texto: fechaLegible(partido.fecha)),
                  _Dato(icono: Icons.place_outlined, texto: partido.ubicacion),
                  if (partido.tiempoMin != null)
                    _Dato(
                      icono: Icons.timer_outlined,
                      texto: '${partido.tiempoMin} min',
                    ),
                  const SizedBox(height: 10),
                  _Cupos(partido: partido),
                  for (final aviso in avisos) ...[
                    const SizedBox(height: 6),
                    aviso,
                  ],
                  if (partido.participantes.isNotEmpty &&
                      alAlternarParticipantes != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: alAlternarParticipantes,
                      child: Text(
                        participantesAbiertos
                            ? 'Ocultar participantes'
                            : 'Ver participantes',
                      ),
                    ),
                  if (participantesAbiertos)
                    Text(
                      partido.participantes
                          .map((participante) => participante.nombre)
                          .join(', '),
                    ),
                  if (participantesAbiertos &&
                      mostrarNombresDeSuplentes &&
                      partido.suplentes.isNotEmpty)
                    Text(
                      'Suplentes: '
                      '${partido.suplentes.map((suplente) => suplente.nombre).join(', ')}',
                    ),
                  if (acciones != null) ...[
                    const SizedBox(height: 10),
                    acciones!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un aviso de una línea dentro de una tarjeta, con un ícono que indica de qué
/// tipo es.
class AvisoTarjeta extends StatelessWidget {
  const AvisoTarjeta({
    super.key,
    required this.icono,
    required this.texto,
    this.color,
    this.negrita = false,
  });

  final IconData icono;
  final String texto;
  final Color? color;
  final bool negrita;

  @override
  Widget build(BuildContext context) {
    final tono = color ?? UniColores.textoSecundario;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: tono),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              color: color ?? UniColores.texto,
              fontWeight: negrita ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lo que dice una lista vacía: qué está pasando y qué hacer a continuación.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: UniColores.primarioSuave,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 44, color: UniColores.primario),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: textos.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: textos.bodyMedium?.copyWith(
                color: UniColores.textoSecundario,
              ),
            ),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}

class _IconoDeporte extends StatelessWidget {
  const _IconoDeporte({required this.deporte});

  final String deporte;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: UniColores.primarioSuave,
        borderRadius: BorderRadius.circular(UniRadio.icono),
      ),
      child: Icon(iconoDeporte(deporte), color: UniColores.primario),
    );
  }
}

class _InsigniaEstado extends StatelessWidget {
  const _InsigniaEstado({required this.partido});

  final Partido partido;

  @override
  Widget build(BuildContext context) {
    final abierto = partido.estado.trim().toLowerCase() == 'cupos abiertos';
    // Texto oscuro sobre un tono claro: legible (AA) en ambos estados.
    final fondo = abierto ? UniColores.exitoSuave : UniColores.neutroSuave;
    final texto = abierto ? UniColores.exito : UniColores.neutro;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(UniRadio.pildora),
      ),
      child: Text(
        partido.estadoTexto,
        style: UniTexto.detalle.copyWith(
          color: texto,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icono, size: 18, color: UniColores.textoSecundario),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _Cupos extends StatelessWidget {
  const _Cupos({required this.partido});

  final Partido partido;

  @override
  Widget build(BuildContext context) {
    final total = partido.cantidadJugadores;
    final ocupados = partido.cantidadParticipantes;
    final avance = total == 0 ? 0.0 : (ocupados / total).clamp(0.0, 1.0);
    final libres = (total - ocupados).clamp(0, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Cupos: $ocupados/$total',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              libres > 0 ? '$libres libres' : 'Sin lugares',
              style: UniTexto.detalle.copyWith(
                color: UniColores.textoSecundario,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(UniRadio.pildora),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: 6,
            backgroundColor: UniColores.pista,
            color: UniColores.primario,
          ),
        ),
      ],
    );
  }
}
