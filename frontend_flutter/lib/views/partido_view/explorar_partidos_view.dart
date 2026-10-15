import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import '../../widgets/ayuda.dart';
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
  final busquedaController = TextEditingController();
  final zonaController = TextEditingController();

  List<Partido> partidos = [];
  bool cargando = true;
  int? partidoUniendoseId;
  int? partidoExpandidoId;
  bool soloConCupos = false;
  String? deporteSeleccionado;
  DateTimeRange? rangoFechas;

  @override
  void initState() {
    super.initState();
    partidoService = widget.partidoService ?? PartidoService();
    cargarPartidos();
  }

  @override
  void dispose() {
    busquedaController.dispose();
    zonaController.dispose();
    super.dispose();
  }

  Future<void> cargarPartidos() async {
    setState(() => cargando = true);
    try {
      final resultado = await partidoService.listarExplorar(
        busqueda: busquedaController.text,
        zona: zonaController.text,
        deporte: deporteSeleccionado,
        desde: rangoFechas?.start,
        hasta: rangoFechas?.end,
        soloConCupos: soloConCupos,
      );
      if (mounted) setState(() => partidos = resultado);
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: rangoFechas,
    );
    if (rango == null) return;
    setState(() => rangoFechas = rango);
    cargarPartidos();
  }

  void filtrarHoy() {
    final hoy = DateTime.now();
    setState(() {
      rangoFechas = DateTimeRange(
        start: DateTime(hoy.year, hoy.month, hoy.day),
        end: DateTime(hoy.year, hoy.month, hoy.day),
      );
    });
    cargarPartidos();
  }

  void filtrarSemana() {
    final hoy = DateTime.now();
    setState(() {
      rangoFechas = DateTimeRange(
        start: DateTime(hoy.year, hoy.month, hoy.day),
        end: DateTime(hoy.year, hoy.month, hoy.day + 6),
      );
    });
    cargarPartidos();
  }

  void limpiarFiltros() {
    setState(() {
      busquedaController.clear();
      zonaController.clear();
      deporteSeleccionado = null;
      rangoFechas = null;
      soloConCupos = false;
    });
    cargarPartidos();
  }

  String fechaTexto(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  String rangoTexto() {
    if (rangoFechas == null) return '';
    final inicio = rangoFechas!.start;
    final fin = rangoFechas!.end;
    return '${inicio.day.toString().padLeft(2, '0')}/'
        '${inicio.month.toString().padLeft(2, '0')} - '
        '${fin.day.toString().padLeft(2, '0')}/'
        '${fin.month.toString().padLeft(2, '0')}';
  }

  String? motivoBloqueo(Partido partido) {
    if (partido.estado == 'equipo completo') {
      return 'El equipo ya está completo';
    }
    if (partido.fecha != null && !partido.fecha!.isAfter(DateTime.now())) {
      return 'La fecha del partido ya pasó';
    }
    if (partido.participantes.any(
      (participante) => participante.id == widget.usuario.id,
    )) {
      return 'Ya estás unido a este partido';
    }
    if (partido.cuposDisponibles <= 0) return 'No quedan cupos disponibles';
    return null;
  }

  Future<void> unirse(Partido partido) async {
    setState(() => partidoUniendoseId = partido.id);

    try {
      await partidoService.unirse(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Te uniste al partido');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => partidoUniendoseId = null);
    }
  }

  Widget filtrosActivos() {
    final hayFiltros =
        busquedaController.text.isNotEmpty ||
        zonaController.text.isNotEmpty ||
        deporteSeleccionado != null ||
        rangoFechas != null ||
        soloConCupos;
    if (!hayFiltros) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (busquedaController.text.isNotEmpty)
          InputChip(
            label: Text('Nombre: ${busquedaController.text}'),
            onDeleted: () {
              setState(() => busquedaController.clear());
              cargarPartidos();
            },
          ),
        if (zonaController.text.isNotEmpty)
          InputChip(
            label: Text('Zona: ${zonaController.text}'),
            onDeleted: () {
              setState(() => zonaController.clear());
              cargarPartidos();
            },
          ),
        if (deporteSeleccionado != null)
          InputChip(
            label: Text('Deporte: $deporteSeleccionado'),
            onDeleted: () {
              setState(() => deporteSeleccionado = null);
              cargarPartidos();
            },
          ),
        if (rangoFechas != null)
          InputChip(
            label: Text(rangoTexto()),
            onDeleted: () {
              setState(() => rangoFechas = null);
              cargarPartidos();
            },
          ),
        if (soloConCupos)
          InputChip(
            label: const Text('Con cupos'),
            onDeleted: () {
              setState(() => soloConCupos = false);
              cargarPartidos();
            },
          ),
      ],
    );
  }

  Widget panelFiltros() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: busquedaController,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: cargarPartidos,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => cargarPartidos(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: zonaController,
              decoration: const InputDecoration(
                labelText: 'Zona o lugar',
                prefixIcon: Icon(Icons.location_on),
              ),
              onSubmitted: (_) => cargarPartidos(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(deporteSeleccionado),
              initialValue: deporteSeleccionado,
              decoration: const InputDecoration(labelText: 'Deporte'),
              hint: const Text('Todos los deportes'),
              items: const [
                DropdownMenuItem(value: 'futbol', child: Text('Fútbol')),
                DropdownMenuItem(value: 'basquet', child: Text('Básquet')),
                DropdownMenuItem(value: 'voley', child: Text('Vóley')),
              ],
              onChanged: (valor) {
                setState(() => deporteSeleccionado = valor);
                cargarPartidos();
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: filtrarHoy,
                  child: const Text('Hoy'),
                ),
                OutlinedButton(
                  onPressed: filtrarSemana,
                  child: const Text('Próximos 7 días'),
                ),
                OutlinedButton(
                  onPressed: elegirRango,
                  child: const Text('Elegir fechas'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo con cupos abiertos'),
              value: soloConCupos,
              onChanged: (valor) {
                setState(() => soloConCupos = valor);
                cargarPartidos();
              },
            ),
            filtrosActivos(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: limpiarFiltros,
                child: const Text('Limpiar filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar partidos'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              mostrarAyuda(
                context,
                'Ayuda para explorar partidos',
                'Utiliza la búsqueda y los filtros para encontrar partidos.\n\n'
                'Pulsa Unirse cuando un partido tenga cupos disponibles.\n\n'
                'Si no puedes unirte, la tarjeta mostrará el motivo.\n\n'
                'Usa Ver participantes para consultar quiénes se unieron.',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          panelFiltros(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : partidos.isEmpty
                    ? const Center(
                        child: Text(
                          'No encontramos partidos que coincidan con los filtros.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: cargarPartidos,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: partidos.length,
                          itemBuilder: (context, index) {
                            final partido = partidos[index];
                            final motivo = motivoBloqueo(partido);
                            final estaExpandido =
                                partidoExpandidoId == partido.id;
                            final estaUniendose =
                                partidoUniendoseId == partido.id;
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Deporte: ${partido.deporteTexto}'),
                                    Text('Organizador: $organizador'),
                                    Text('Ubicación: ${partido.ubicacion}'),
                                    Text('Fecha: ${fechaTexto(partido.fecha)}'),
                                    Text(
                                      'Cupos: ${partido.cantidadParticipantes}/'
                                      '${partido.cantidadJugadores}',
                                    ),
                                    Text('Estado: ${partido.estadoTexto}'),
                                    Text(
                                      'Participantes: '
                                      '${partido.cantidadParticipantes}',
                                    ),
                                    if (partido.participantes.isNotEmpty)
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            partidoExpandidoId = estaExpandido
                                                ? null
                                                : partido.id;
                                          });
                                        },
                                        child: Text(
                                          estaExpandido
                                              ? 'Ocultar participantes'
                                              : 'Ver participantes',
                                        ),
                                      ),
                                    if (estaExpandido)
                                      Text(
                                        partido.participantes
                                            .map(
                                              (participante) =>
                                                  participante.nombre,
                                            )
                                            .join(', '),
                                      ),
                                    const SizedBox(height: 8),
                                    if (motivo == null)
                                      ElevatedButton(
                                        onPressed: estaUniendose
                                            ? null
                                            : () => unirse(partido),
                                        child: estaUniendose
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Unirse'),
                                      )
                                    else
                                      Text(
                                        motivo,
                                        style: TextStyle(
                                          color: motivo ==
                                                  'Ya estás unido a este partido'
                                              ? Colors.green
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.error,
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
          ),
        ],
      ),
    );
  }
}
