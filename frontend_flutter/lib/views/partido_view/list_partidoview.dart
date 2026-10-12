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

    try {
      if (partido == null) {
        await partidoService.crear(
          PartidoCreateRequest(
            nombre: datos['nombre'],
            cantidadJugadores: datos['cantidadJugadores'],
            ubicacion: datos['ubicacion'],
            tiempoMin: datos['tiempoMin'],
            fecha: datos['fecha'],
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
          ),
        );
      }

      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Partido guardado');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
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

    try {
      await partidoService.eliminar(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Partido eliminado');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    }
  }

  Future<void> completarEquipo(Partido partido) async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis partidos')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : partidos.isEmpty
          ? const Center(child: Text('No tienes partidos todavía'))
          : RefreshIndicator(
              onRefresh: cargarPartidos,
              child: ListView.builder(
                itemCount: partidos.length,
                itemBuilder: (context, index) {
                  final partido = partidos[index];

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(partido.nombre),
                      subtitle: Text(
                        '${partido.ubicacion}\n'
                        'Jugadores: ${partido.cantidadJugadores}\n'
                        'Duración: ${partido.tiempoMin ?? 'No definida'}\n'
                        'Estado: ${partido.estado}',
                      ),
                      //isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (partido.estado.trim().toLowerCase() ==
                              'cupos abiertos')
                            ElevatedButton(
                              onPressed: () => completarEquipo(partido),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Completar Equipo'),
                            ),

                          // Botón editar
                          IconButton(
                            onPressed: () => abrirFormulario(partido: partido),
                            icon: const Icon(Icons.edit),
                          ),

                          // Botón eliminar
                          IconButton(
                            onPressed: () => borrarPartido(partido),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
