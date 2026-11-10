import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import '../../widgets/mensaje.dart';
import 'resultado_partido_view.dart';

/// "Me uní" tab: matches the user joined (as player or substitute),
/// with the leave action available right where the user looks for it.
class PartidosUnidosView extends StatefulWidget {
  const PartidosUnidosView({
    super.key,
    required this.usuario,
    required this.partidoService,
  });

  final Usuario usuario;
  final PartidoService partidoService;

  @override
  State<PartidosUnidosView> createState() => _PartidosUnidosViewState();
}

class _PartidosUnidosViewState extends State<PartidosUnidosView> {
  List<Partido> partidos = [];
  bool cargando = true;
  String? mensajeError;
  int? partidoSaliendoId;

  @override
  void initState() {
    super.initState();
    cargarPartidos();
  }

  bool estaUnido(Partido partido) =>
      partido.participantes.any((p) => p.id == widget.usuario.id) ||
      partido.suplentes.any((s) => s.id == widget.usuario.id);

  bool yaSeJugo(Partido partido) {
    final fecha = partido.fecha;
    return fecha != null && !fecha.isAfter(DateTime.now());
  }

  bool esSuplente(Partido partido) =>
      partido.suplentes.any((s) => s.id == widget.usuario.id);

  Future<void> cargarPartidos() async {
    setState(() {
      cargando = true;
      mensajeError = null;
    });
    try {
      final todos = await widget.partidoService.listarParticipando();
      if (!mounted) return;
      setState(() => partidos = todos.where(estaUnido).toList());
    } catch (_) {
      if (mounted) {
        setState(() => mensajeError = 'No se pudieron cargar tus partidos');
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> salir(Partido partido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir del partido'),
        content: const Text('¿Quieres salir de este partido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            key: const Key('confirmar-salir-partido'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => partidoSaliendoId = partido.id);
    try {
      await widget.partidoService.salir(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Saliste del partido');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => partidoSaliendoId = null);
    }
  }

  String fechaTexto(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (mensajeError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensajeError!),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: cargarPartidos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (partidos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Todavía no te uniste a ningún partido'),
              SizedBox(height: 8),
              Text(
                'Busca uno en Explorar partidos desde el inicio.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cargarPartidos,
      child: ListView.builder(
        itemCount: partidos.length,
        itemBuilder: (context, index) {
          final partido = partidos[index];
          final saliendo = partidoSaliendoId == partido.id;

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(partido.nombre),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deporte: ${partido.deporteTexto}'),
                  Text(
                    'Organizador: ${partido.organizador?.nombre ?? 'Sin datos'}',
                  ),
                  Text('Ubicación: ${partido.ubicacion}'),
                  Text('Fecha: ${fechaTexto(partido.fecha)}'),
                  Text('Estado: ${partido.estadoTexto}'),
                  if (esSuplente(partido))
                    const Text('Te uniste como suplente'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: Key('boton-resultado-partido-${partido.id}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultadoPartidoView(
                          partidoId: partido.id,
                          partidoService: widget.partidoService,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.scoreboard_outlined),
                    label: const Text('Resultado'),
                  ),
                  // The API rejects leaving a played match, so the button
                  // would only fail.
                  if (!yaSeJugo(partido)) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      key: Key('boton-salir-partido-${partido.id}'),
                      onPressed: saliendo ? null : () => salir(partido),
                      icon: const Icon(Icons.logout),
                      label: Text(
                        saliendo ? 'Saliendo...' : 'Salir del partido',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
