import 'package:flutter/material.dart';

import '../../models/historial_partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import 'explorar_partidos_view.dart';

class HistorialPartidosView extends StatefulWidget {
  const HistorialPartidosView({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<HistorialPartidosView> createState() => _HistorialPartidosViewState();
}

class _HistorialPartidosViewState extends State<HistorialPartidosView> {
  final PartidoService partidoService = PartidoService();

  List<HistorialPartido> historial = [];
  bool cargando = true;
  String? mensajeError;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    setState(() {
      cargando = true;
      mensajeError = null;
    });

    try {
      final resultado = await partidoService.listarHistorial();

      if (!mounted) return;

      setState(() {
        historial = resultado;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        mensajeError = 'No se pudo cargar el historial';
      });
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  String fechaYHoraTexto(DateTime fecha) {
    final fechaLocal = fecha.toLocal();

    final dia = fechaLocal.day.toString().padLeft(2, '0');
    final mes = fechaLocal.month.toString().padLeft(2, '0');
    final hora = fechaLocal.hour.toString().padLeft(2, '0');
    final minuto = fechaLocal.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${fechaLocal.year} a las $hora:$minuto';
  }

  String fechaPartidoTexto(DateTime? fecha) {
    if (fecha == null) {
      return 'Fecha no disponible';
    }

    final fechaLocal = fecha.toLocal();
    final dia = fechaLocal.day.toString().padLeft(2, '0');
    final mes = fechaLocal.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fechaLocal.year}';
  }

  Future<void> abrirExplorarPartidos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExplorarPartidosView(usuario: widget.usuario),
      ),
    );

    await cargarHistorial();
  }

  Widget construirEstadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Todavía no participaste en ningún partido',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Explora los partidos disponibles y únete a uno.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: abrirExplorarPartidos,
              icon: const Icon(Icons.search),
              label: const Text('Explorar partidos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              mensajeError ?? 'Ocurrió un error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: cargarHistorial,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget construirLista() {
    return RefreshIndicator(
      onRefresh: cargarHistorial,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: historial.length,
        itemBuilder: (context, index) {
          final evento = historial[index];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.sports_soccer)),
              title: Text(
                evento.nombrePartido,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(evento.accionTexto),
                    Text('Deporte: ${evento.deporteTexto}'),
                    Text('Ubicación: ${evento.ubicacion}'),
                    Text(
                      'Fecha del partido: '
                      '${fechaPartidoTexto(evento.fechaPartido)}',
                    ),
                    Text('Estado: ${evento.estadoTexto}'),
                    const SizedBox(height: 6),
                    Text(
                      'Registrado: '
                      '${fechaYHoraTexto(evento.fechaEvento)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget contenido;

    if (cargando) {
      contenido = const Center(child: CircularProgressIndicator());
    } else if (mensajeError != null) {
      contenido = construirError();
    } else if (historial.isEmpty) {
      contenido = construirEstadoVacio();
    } else {
      contenido = construirLista();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi historial')),
      body: contenido,
    );
  }
}
