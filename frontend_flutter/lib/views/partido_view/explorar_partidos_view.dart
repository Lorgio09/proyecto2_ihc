import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import '../../widgets/mensaje.dart';

class ExplorarPartidosView extends StatefulWidget {
  const ExplorarPartidosView({
    super.key,
    required this.usuario,
    this.partidoService,
  });

  final Usuario usuario;
  final PartidoService? partidoService;

  @override
  State<ExplorarPartidosView> createState() => _ExplorarPartidosViewState();
}

class _ExplorarPartidosViewState extends State<ExplorarPartidosView> {
  late final PartidoService partidoService;
  List<Partido> partidos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    partidoService = widget.partidoService ?? PartidoService();
    cargarPartidos();
  }

  Future<void> cargarPartidos() async {
    setState(() => cargando = true);

    try {
      final resultado = await partidoService.listarExplorar();
      if (!mounted) return;
      setState(() => partidos = resultado);
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  String? motivoBloqueo(Partido partido) {
    if (partido.estado == 'equipo completo') {
      return 'El equipo ya esta completo';
    }

    if (partido.fecha != null && !partido.fecha!.isAfter(DateTime.now())) {
      return 'La fecha del partido ya paso';
    }

    if (partido.participantes.any(
      (participante) => participante.id == widget.usuario.id,
    )) {
      return 'Ya estas unido a este partido';
    }

    if (partido.cuposDisponibles <= 0) {
      return 'No quedan cupos disponibles';
    }

    return null;
  }

  String fechaTexto(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String participantesTexto(Partido partido) {
    if (partido.participantes.isEmpty) return 'Nadie se ha unido todavía';
    return partido.participantes
        .map((participante) => participante.nombre)
        .join(', ');
  }

  Future<void> unirse(Partido partido) async {
    try {
      await partidoService.unirse(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Te uniste al partido');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar partidos')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : partidos.isEmpty
          ? const Center(child: Text('No hay partidos para explorar'))
          : RefreshIndicator(
              onRefresh: cargarPartidos,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: partidos.length,
                itemBuilder: (context, index) {
                  final partido = partidos[index];
                  final motivo = motivoBloqueo(partido);
                  final organizador =
                      partido.organizador?.nombre ?? 'Sin nombre';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partido.nombre,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text('Organizador: $organizador'),
                          Text('Ubicación: ${partido.ubicacion}'),
                          Text('Fecha: ${fechaTexto(partido.fecha)}'),
                          Text(
                            'Cupos: ${partido.cantidadParticipantes}/${partido.cantidadJugadores}',
                          ),
                          Text('Participantes: ${participantesTexto(partido)}'),
                          const SizedBox(height: 8),
                          if (motivo == null)
                            ElevatedButton(
                              onPressed: () => unirse(partido),
                              child: const Text('Unirse'),
                            )
                          else
                            Text(
                              motivo,
                              style: TextStyle(
                                color: motivo == 'Ya estas unido a este partido'
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
