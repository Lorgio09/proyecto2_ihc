import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../models/partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import '../../widgets/ayuda.dart';
import '../../widgets/mensaje.dart';
import '../../widgets/tarjeta_partido.dart';
import 'confirmar_salida.dart';

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
  int? partidoSaliendoId;
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

  // Solo la petición más reciente puede actualizar la pantalla: una respuesta
  // vieja que llega tarde pisaría los resultados de la búsqueda actual.
  int _ultimaCarga = 0;

  Future<void> cargarPartidos() async {
    final carga = ++_ultimaCarga;
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
      if (mounted && carga == _ultimaCarga) {
        setState(() => partidos = resultado);
      }
    } catch (error) {
      if (mounted && carga == _ultimaCarga) {
        final mensaje = error is PartidoError
            ? error.mensaje
            : 'No se pudieron cargar los partidos disponibles';
        mostrarMensajeConAccion(
          context,
          mensaje,
          textoAccion: 'Reintentar',
          accion: cargarPartidos,
        );
      }
    } finally {
      if (mounted && carga == _ultimaCarga) setState(() => cargando = false);
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
    if (estaUnido(partido)) return null;
    // Cerrado por el organizador aunque quedan cupos. Un equipo que está
    // completo solo porque se ocuparon todos los cupos sigue aceptando
    // suplentes.
    if (partido.estado == 'equipo completo' && partido.cuposDisponibles > 0) {
      return 'El equipo ya está completo';
    }
    if (partido.fecha != null && !partido.fecha!.isAfter(DateTime.now())) {
      return 'La fecha del partido ya pasó';
    }
    return null;
  }

  bool estaUnido(Partido partido) =>
      partido.participantes.any(
        (participante) => participante.id == widget.usuario.id,
      ) ||
      posicionSuplente(partido) != null;

  /// Lugar en la fila de suplentes (empieza en 1), o null si no es suplente.
  int? posicionSuplente(Partido partido) {
    final indice = partido.suplentes.indexWhere(
      (suplente) => suplente.id == widget.usuario.id,
    );
    return indice == -1 ? null : indice + 1;
  }

  Future<void> unirse(Partido partido) async {
    // Evento de inicio del flujo para unirse; el de éxito (partido_unido) lo
    // registra el backend cuando la unión queda guardada.
    partidoService.registrarEvento('union_iniciada', {
      'deporte': partido.deporte,
    });
    setState(() => partidoUniendoseId = partido.id);

    try {
      final actualizado = await partidoService.unirse(partido.id);
      await cargarPartidos();
      if (mounted) {
        mostrarMensaje(
          context,
          posicionSuplente(actualizado) != null
              ? 'Te uniste como suplente'
              : 'Te uniste al partido',
        );
      }
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => partidoUniendoseId = null);
    }
  }

  Future<void> reconfirmar(Partido partido) async {
    try {
      await partidoService.reconfirmar(partido.id);
      await cargarPartidos();
      if (mounted)
        mostrarMensaje(context, 'Confirmaste tu lugar en el partido');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    }
  }

  Future<void> salir(Partido partido) async {
    // Inicio del embudo "salir de un partido"; baja_registrada viene de la API.
    partidoService.registrarEvento('baja_iniciada', {});
    final confirmar = await confirmarSalida(
      context,
      partido,
      widget.usuario.id,
    );
    if (!confirmar || !mounted) return;

    setState(() => partidoSaliendoId = partido.id);
    try {
      await partidoService.salir(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Saliste del partido');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => partidoSaliendoId = null);
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

  /// Filtros compactos: búsqueda, lugar y deporte en una fila, chips rápidos de
  /// fecha y los filtros activos. Antes ocupaban media pantalla
  /// (retroalimentación de la Clase 19).
  Widget panelFiltros() {
    final hayFiltros =
        busquedaController.text.isNotEmpty ||
        zonaController.text.isNotEmpty ||
        deporteSeleccionado != null ||
        rangoFechas != null ||
        soloConCupos;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: busquedaController,
            decoration: InputDecoration(
              labelText: 'Buscar por nombre',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'Buscar partidos',
                onPressed: cargarPartidos,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
            onSubmitted: (_) => cargarPartidos(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: zonaController,
                  decoration: const InputDecoration(
                    labelText: 'Zona o lugar',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    isDense: true,
                  ),
                  onSubmitted: (_) => cargarPartidos(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(deporteSeleccionado),
                  initialValue: deporteSeleccionado,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Deporte',
                    isDense: true,
                  ),
                  hint: const Text('Todos'),
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
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.today, size: 18),
                  label: const Text('Hoy'),
                  onPressed: filtrarHoy,
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: const Text('Próximos 7 días'),
                  onPressed: filtrarSemana,
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Elegir fechas'),
                  onPressed: elegirRango,
                ),
                FilterChip(
                  label: const Text('Con cupos'),
                  selected: soloConCupos,
                  onSelected: (valor) {
                    setState(() => soloConCupos = valor);
                    cargarPartidos();
                  },
                ),
              ],
            ),
          ),
          if (hayFiltros) ...[
            const SizedBox(height: 4),
            filtrosActivos(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: limpiarFiltros,
                child: const Text('Limpiar filtros'),
              ),
            ),
          ],
        ],
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
      // Los filtros se desplazan con la lista: con filtros activos el panel
      // crece y, fijo arriba, se desbordaba en pantallas pequeñas.
      body: RefreshIndicator(
        onRefresh: cargarPartidos,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: cargando || partidos.isEmpty ? 2 : partidos.length + 1,
          itemBuilder: (context, indice) {
            if (indice == 0) return panelFiltros();
            if (cargando) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (partidos.isEmpty) {
              return const EstadoVacio(
                icono: Icons.search_off,
                titulo:
                    'No encontramos partidos que coincidan con los filtros.',
                mensaje: 'Prueba con otra zona, deporte o fecha.',
              );
            }
            final partido = partidos[indice - 1];
            final motivo = motivoBloqueo(partido);
            final estaExpandido = partidoExpandidoId == partido.id;
            final estaUniendose = partidoUniendoseId == partido.id;
            final estaSaliendo = partidoSaliendoId == partido.id;
            final estaUnidoAlPartido = estaUnido(partido);
            final organizador = partido.organizador?.nombre ?? 'Sin nombre';

            final reconfirma = partido.debeReconfirmar(widget.usuario.id);
            final spinner = const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
            // Unirse y salir tienen el mismo tamaño: salir debe ser tan fácil
            // de encontrar como unirse (Clase 22, simetría).
            final tamano = ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
            );

            return TarjetaPartido(
              partido: partido,
              organizador: organizador,
              participantesAbiertos: estaExpandido,
              alAlternarParticipantes: () => setState(() {
                partidoExpandidoId = estaExpandido ? null : partido.id;
              }),
              avisos: [
                if (partido.cantidadSuplentes > 0)
                  AvisoTarjeta(
                    icono: Icons.event_seat_outlined,
                    texto: 'Suplentes: ${partido.cantidadSuplentes}',
                  ),
                if (posicionSuplente(partido) != null)
                  AvisoTarjeta(
                    icono: Icons.format_list_numbered,
                    texto:
                        'Eres suplente (posición ${posicionSuplente(partido)})',
                  ),
                if (partido.motivoReprogramacion != null)
                  AvisoTarjeta(
                    icono: Icons.event_repeat,
                    texto: 'Reprogramado: ${partido.motivoReprogramacion}',
                  ),
                if (reconfirma)
                  const AvisoTarjeta(
                    icono: Icons.help_outline,
                    texto: 'El partido cambió. ¿Sigues jugando?',
                    negrita: true,
                  ),
              ],
              acciones: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reconfirma)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton(
                        key: const Key('boton-reconfirmar-partido'),
                        style: tamano,
                        onPressed: () => reconfirmar(partido),
                        child: const Text('Sigo jugando'),
                      ),
                    ),
                  if (estaUnidoAlPartido)
                    OutlinedButton(
                      key: const Key('boton-salir-partido'),
                      style: tamano,
                      onPressed: estaSaliendo ? null : () => salir(partido),
                      child: estaSaliendo
                          ? spinner
                          : Text(
                              reconfirma ? 'Me retiro' : 'Salir del partido',
                            ),
                    )
                  else if (motivo == null)
                    FilledButton(
                      key: const Key('boton-unirse-partido'),
                      style: tamano,
                      onPressed: estaUniendose ? null : () => unirse(partido),
                      child: estaUniendose
                          ? spinner
                          : Text(
                              partido.cuposDisponibles <= 0
                                  ? 'Unirse como suplente'
                                  : 'Unirse',
                            ),
                    )
                  else
                    AvisoTarjeta(
                      icono: motivo == 'Ya estás unido a este partido'
                          ? Icons.check_circle_outline
                          : Icons.block,
                      color: motivo == 'Ya estás unido a este partido'
                          ? UniColores.exito
                          : UniColores.error,
                      texto: motivo,
                      negrita: true,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
