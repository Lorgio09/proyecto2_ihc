import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../services/partido.dart';
import '../../widgets/mensaje.dart';
import 'formulario_partido.dart';

class ListPartidoView extends StatefulWidget {
  const ListPartidoView({super.key, this.partidoService});

  final PartidoService? partidoService;

  @override
  State<ListPartidoView> createState() => _ListPartidoViewState();
}

class _ListPartidoViewState extends State<ListPartidoView> {
  late final PartidoService partidoService;
  List<Partido> partidos = [];
  bool cargando = true;
  bool guardandoPartido = false;
  int? partidoEliminandoId;
  int? partidoCompletandoId;

  @override
  void initState() {
    super.initState();
    partidoService = widget.partidoService ?? PartidoService();
    cargarPartidos();
  }

  Future<void> cargarPartidos() async {
    setState(() {
      cargando = true;
    });

    try {
      final resultado = await partidoService.listar();
      setState(() {
        partidos = resultado;
      });
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> abrirFormulario({Partido? partido}) async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FormularioPartido(partido: partido),
    );

    if (datos == null) return;

    setState(() => guardandoPartido = true);

    try {
      if (partido == null) {
        await partidoService.crear(
          PartidoCreateRequest(
            nombre: datos['nombre'],
            cantidadJugadores: datos['cantidadJugadores'],
            ubicacion: datos['ubicacion'],
            tiempoMin: datos['tiempoMin'],
            fecha: datos['fecha'],
            deporte: datos['deporte'],
          ),
        );
      } else {
        await partidoService.actualizar(
          partido.id,
          PartidoUpdateRequest(
            nombre: datos['nombre'],
            cantidadJugadores: datos['cantidadJugadores'],
            ubicacion: datos['ubicacion'],
            tiempoMin: datos['tiempoMin'],
            fecha: datos['fecha'],
            deporte: datos['deporte'],
          ),
        );
      }

      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Partido guardado');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => guardandoPartido = false);
    }
  }

  Future<void> borrarPartido(Partido partido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar partido'),
        content: const Text('¿Quieres eliminar este partido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => partidoEliminandoId = partido.id);

    try {
      await partidoService.eliminar(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Partido eliminado');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => partidoEliminandoId = null);
    }
  }

  Future<void> completarEquipo(Partido partido) async {
    setState(() => partidoCompletandoId = partido.id);

    try {
      await partidoService.completarEquipo(partido.id);
      await cargarPartidos();
      if (mounted) {
        mostrarMensaje(context, 'Equipo completado');
      }
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => partidoCompletandoId = null);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis partidos')),
      body: guardandoPartido
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Guardando partido...'),
                ],
              ),
            )
          : cargando
          ? const Center(child: CircularProgressIndicator())
          : partidos.isEmpty
          ? const Center(child: Text('No tienes partidos todavía'))
          : RefreshIndicator(
              onRefresh: cargarPartidos,
              child: ListView.builder(
                itemCount: partidos.length,
                itemBuilder: (context, index) {
                  final partido = partidos[index];
                  final estaEliminando = partidoEliminandoId == partido.id;
                  final estaCompletando = partidoCompletandoId == partido.id;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(partido.nombre),
                      subtitle: Text(
                        'Deporte: ${partido.deporte}\n'
                        '${partido.ubicacion}\n'
                        'Fecha: ${fechaTexto(partido.fecha)}\n'
                        'Cupos: ${partido.cantidadParticipantes}/'
                        '${partido.cantidadJugadores}\n'
                        'Duración: ${partido.tiempoMin ?? 'No definida'}\n'
                        'Participantes: ${participantesTexto(partido)}\n'
                        'Estado: ${partido.estado}',
                      ),
                      //isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (partido.estado.trim().toLowerCase() ==
                              'cupos abiertos')
                            ElevatedButton(
                              onPressed: estaCompletando
                                  ? null
                                  : () => completarEquipo(partido),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: estaCompletando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Completar Equipo'),
                            ),

                          // Botón editar
                          IconButton(
                            onPressed: () => abrirFormulario(partido: partido),
                            icon: const Icon(Icons.edit),
                          ),

                          // Botón eliminar
                          IconButton(
                            onPressed: estaEliminando
                                ? null
                                : () => borrarPartido(partido),
                            icon: estaEliminando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: guardandoPartido ? null : () => abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
