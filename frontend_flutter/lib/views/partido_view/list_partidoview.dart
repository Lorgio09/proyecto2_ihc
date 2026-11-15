import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import '../../widgets/ayuda.dart';
import '../../widgets/mensaje.dart';
import '../../widgets/tarjeta_partido.dart';
import 'formulario_partido.dart';
import 'partidos_unidos_view.dart';
import 'reprogramar_partido.dart';
import 'resultado_partido_view.dart';

class ListPartidoView extends StatefulWidget {
  const ListPartidoView({super.key, this.partidoService, this.usuario});

  final PartidoService? partidoService;

  /// When provided, the view shows the "Organizo" / "Me uní" tabs.
  final Usuario? usuario;

  @override
  State<ListPartidoView> createState() => _ListPartidoViewState();
}

class _ListPartidoViewState extends State<ListPartidoView>
    with SingleTickerProviderStateMixin {
  late final PartidoService partidoService;
  TabController? tabController;
  final busquedaController = TextEditingController();
  List<Partido> partidos = [];
  bool cargando = true;
  bool guardandoPartido = false;
  int? partidoEliminandoId;
  int? partidoCompletandoId;
  int? partidoReabriendoId;
  int? partidoExpandidoId;
  String estadoFiltro = 'todos';
  String busquedaAplicada = '';
  String estadoFiltroAplicado = 'todos';

  @override
  void initState() {
    super.initState();
    partidoService = widget.partidoService ?? PartidoService();
    if (widget.usuario != null) {
      tabController = TabController(length: 2, vsync: this)
        ..addListener(() => setState(() {}));
    }
    cargarPartidos();
  }

  @override
  void dispose() {
    tabController?.dispose();
    busquedaController.dispose();
    super.dispose();
  }

  List<Partido> get partidosVisibles {
    final texto = busquedaAplicada;
    return partidos.where((partido) {
      final coincideTexto =
          texto.isEmpty ||
          partido.nombre.toLowerCase().contains(texto) ||
          partido.ubicacion.toLowerCase().contains(texto);
      final coincideEstado =
          estadoFiltroAplicado == 'todos' ||
          partido.estado.trim().toLowerCase() == estadoFiltroAplicado;
      return coincideTexto && coincideEstado;
    }).toList();
  }

  bool get hayFiltrosActivos =>
      busquedaAplicada.isNotEmpty || estadoFiltroAplicado != 'todos';

  bool get hayFiltrosPendientes =>
      busquedaController.text.trim().toLowerCase() != busquedaAplicada ||
      estadoFiltro != estadoFiltroAplicado;

  void aplicarFiltros() {
    setState(() {
      busquedaAplicada = busquedaController.text.trim().toLowerCase();
      estadoFiltroAplicado = estadoFiltro;
    });
  }

  void limpiarFiltros() {
    setState(() {
      busquedaController.clear();
      estadoFiltro = 'todos';
      busquedaAplicada = '';
      estadoFiltroAplicado = 'todos';
    });
  }

  /// Compact filters: search on top, state and "Buscar" in one row, and
  /// "Limpiar filtros" only when there is something to clear.
  Widget panelFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: busquedaController,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => aplicarFiltros(),
            decoration: const InputDecoration(
              labelText: 'Buscar por nombre o ubicación',
              hintText: 'Ej. Oriente o Cancha central',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: estadoFiltro,
                  isDense: true,
                  // Shares the row with the button: it must shrink, not overflow.
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por estado',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(
                      value: 'cupos abiertos',
                      child: Text('Cupos abiertos'),
                    ),
                    DropdownMenuItem(
                      value: 'equipo completo',
                      child: Text('Equipo completo'),
                    ),
                  ],
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() => estadoFiltro = valor);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Aplicar la búsqueda y el estado seleccionado',
                child: FilledButton(
                  onPressed: hayFiltrosPendientes ? aplicarFiltros : null,
                  child: const Text('Buscar partidos'),
                ),
              ),
            ],
          ),
          if (hayFiltrosActivos)
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Borrar búsqueda y estado seleccionado',
                child: TextButton(
                  onPressed: limpiarFiltros,
                  child: const Text('Limpiar filtros'),
                ),
              ),
            ),
        ],
      ),
    );
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
      if (mounted) {
        final mensaje = error is PartidoError
            ? error.mensaje
            : 'No se pudieron cargar tus partidos';
        mostrarMensajeConAccion(
          context,
          mensaje,
          textoAccion: 'Reintentar',
          accion: cargarPartidos,
        );
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void _fallo(String flujo, String motivo) {
    partidoService.registrarEvento('tarea_fallida', {
      'flujo': flujo,
      'motivo': motivo,
    });
  }

  Future<void> abrirFormulario({Partido? partido}) async {
    final creando = partido == null;
    // Start of the "create a match" funnel (editing is not part of it).
    if (creando) partidoService.registrarEvento('partido_creacion_iniciada', {});
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FormularioPartido(
        partido: partido,
        alFallar: creando ? (motivo) => _fallo('crear_partido', motivo) : null,
      ),
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
            key: const Key('confirmar-eliminar-partido'),
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

  Future<void> reprogramarPartido(Partido partido) async {
    if (partido.tieneRespuestasPendientes) {
      mostrarMensaje(
        context,
        'Espera a que todos los titulares respondan antes de reprogramar otra vez',
      );
      _fallo('reprogramar', 'REPROGRAMACION_PENDIENTE');
      return;
    }

    partidoService.registrarEvento('reprogramacion_iniciada', {
      'deporte': partido.deporte,
    });
    final datos = await showDialog<DatosReprogramacion>(
      context: context,
      builder: (context) => ReprogramarPartidoDialog(
        partido: partido,
        alFallar: (motivo) => _fallo('reprogramar', motivo),
      ),
    );
    if (datos == null) return;

    try {
      await partidoService.reprogramar(
        partido.id,
        fecha: datos.fecha,
        ubicacion: datos.ubicacion,
        motivo: datos.motivo,
      );
      await cargarPartidos();
      if (mounted) {
        mostrarMensaje(
          context,
          'Partido reprogramado. Avisamos a los titulares',
        );
      }
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    }
  }

  Future<void> completarEquipo(Partido partido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar equipo'),
        content: const Text(
          'Al completar el equipo se cerrarán los cupos y otros usuarios '
          'no podrán unirse al partido. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar-completar-partido'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completar equipo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

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

  Future<void> reabrirEquipo(Partido partido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reabrir equipo'),
        content: const Text('¿Quieres volver a abrir los cupos del partido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            key: const Key('confirmar-reabrir-partido'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, reabrir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => partidoReabriendoId = partido.id);
    try {
      await partidoService.reabrir(partido.id);
      await cargarPartidos();
      if (mounted) mostrarMensaje(context, 'Equipo reabierto');
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => partidoReabriendoId = null);
    }
  }

  String fechaTexto(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  // Acciones de una tarjeta (completar/reabrir, editar, eliminar).
  // Antes estaban en el `trailing` del ListTile y estrechaban el texto;
  // ahora se dibujan debajo del contenido. La lógica de cada botón no cambia.
  Future<void> abrirResultado(Partido partido) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultadoPartidoView(
          partidoId: partido.id,
          partidoService: partidoService,
        ),
      ),
    );
  }

  /// The main action stays visible; the rest live in the "⋮" menu so the card
  /// is not crowded (H8).
  Widget _construirAcciones(Partido partido) {
    final estado = partido.estado.trim().toLowerCase();
    final estaCompletando = partidoCompletandoId == partido.id;
    final estaReabriendo = partidoReabriendoId == partido.id;

    Widget cargando() => const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );

    if (estado == 'cupos abiertos') {
      return ElevatedButton.icon(
        key: const Key('boton-completar-partido'),
        onPressed: estaCompletando ? null : () => completarEquipo(partido),
        icon: const Icon(Icons.lock_outline, size: 18),
        label: estaCompletando ? cargando() : const Text('Completar equipo'),
      );
    }
    if (estado == 'equipo completo') {
      return ElevatedButton.icon(
        key: const Key('boton-reabrir-partido'),
        onPressed: estaReabriendo ? null : () => reabrirEquipo(partido),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.lock_open, size: 18),
        label: estaReabriendo ? cargando() : const Text('Reabrir equipo'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _menuAcciones(Partido partido) {
    if (partidoEliminandoId == partido.id) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    PopupMenuItem<String> opcion(
      String valor,
      String texto,
      IconData icono, {
      Key? key,
      Color? color,
    }) {
      return PopupMenuItem<String>(
        key: key,
        value: valor,
        child: Row(
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (valor) {
        switch (valor) {
          case 'reprogramar':
            reprogramarPartido(partido);
          case 'resultado':
            abrirResultado(partido);
          case 'editar':
            abrirFormulario(partido: partido);
          case 'eliminar':
            borrarPartido(partido);
        }
      },
      itemBuilder: (context) => [
        opcion(
          'reprogramar',
          'Reprogramar',
          Icons.event_repeat,
          key: const Key('boton-reprogramar-partido'),
        ),
        opcion(
          'resultado',
          'Resultado del partido',
          Icons.scoreboard_outlined,
          key: const Key('boton-resultado-partido'),
        ),
        opcion('editar', 'Editar partido', Icons.edit_outlined),
        opcion(
          'eliminar',
          'Eliminar partido',
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    final tabs = tabController;
    final enOrganizo = tabs == null || tabs.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis partidos'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              mostrarAyuda(
                context,
                'Ayuda para administrar partidos',
                (tabs != null
                        ? 'En Organizo están los partidos que creaste.\n\n'
                              'En Me uní están los partidos a los que te '
                              'uniste; desde ahí puedes salir de ellos.\n\n'
                        : '') +
                    'Pulsa el botón + para crear un partido.\n\n'
                        'Usa el lápiz para editarlo y la papelera para eliminarlo.\n\n'
                        'Completar equipo cierra los cupos y evita que otros '
                        'usuarios se unan.\n\n'
                        'Usa Ver participantes para conocer quiénes se unieron.',
              );
            },
          ),
        ],
        bottom: tabs == null
            ? null
            : TabBar(
                controller: tabs,
                tabs: const [
                  Tab(
                    key: Key('pestana-organizo'),
                    icon: Icon(Icons.edit_calendar),
                    text: 'Organizo',
                  ),
                  Tab(
                    key: Key('pestana-me-uni'),
                    icon: Icon(Icons.group),
                    text: 'Me uní',
                  ),
                ],
              ),
      ),
      body: tabs == null || usuario == null
          ? _cuerpoOrganizo()
          : TabBarView(
              controller: tabs,
              children: [
                _cuerpoOrganizo(),
                PartidosUnidosView(
                  usuario: usuario,
                  partidoService: partidoService,
                ),
              ],
            ),
      floatingActionButton: enOrganizo
          ? FloatingActionButton.extended(
              tooltip: 'Nuevo partido',
              onPressed: guardandoPartido ? null : () => abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo partido'),
            )
          : null,
    );
  }

  Widget _cuerpoOrganizo() {
    return guardandoPartido
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
        : Column(
            children: [
              if (partidos.isNotEmpty) panelFiltros(),
              Expanded(
                child: partidos.isEmpty
                    ? const EstadoVacio(
                        icono: Icons.sports_soccer,
                        titulo: 'No tienes partidos todavía',
                        mensaje:
                            'Crea el primero con el botón "Nuevo partido" y '
                            'compártelo para completar tu equipo.',
                      )
                    : partidosVisibles.isEmpty
                    ? EstadoVacio(
                        icono: Icons.search_off,
                        titulo: 'No encontramos partidos con estos filtros',
                        mensaje: 'Prueba con otra búsqueda u otro estado.',
                        accion: TextButton(
                          onPressed: limpiarFiltros,
                          child: const Text('Limpiar filtros'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: cargarPartidos,
                        child: ListView.builder(
                          itemCount: partidosVisibles.length,
                          itemBuilder: (context, index) {
                            final partido = partidosVisibles[index];
                            final estaExpandido =
                                partidoExpandidoId == partido.id;

                            final error = Theme.of(context).colorScheme.error;
                            return TarjetaPartido(
                              partido: partido,
                              participantesAbiertos: estaExpandido,
                              alAlternarParticipantes: () => setState(() {
                                partidoExpandidoId = estaExpandido
                                    ? null
                                    : partido.id;
                              }),
                              mostrarNombresDeSuplentes: true,
                              avisos: [
                                if (partido.motivoReprogramacion != null)
                                  AvisoTarjeta(
                                    icono: Icons.event_repeat,
                                    texto:
                                        'Reprogramado: ${partido.motivoReprogramacion}',
                                  ),
                                if (partido.tieneRespuestasPendientes)
                                  AvisoTarjeta(
                                    icono: Icons.hourglass_top,
                                    texto:
                                        'Esperando respuesta de: '
                                        '${partido.pendientesConfirmar.map((usuario) => usuario.nombre).join(', ')}',
                                  ),
                                if (partido.bajasTardias.isNotEmpty)
                                  AvisoTarjeta(
                                    icono: Icons.warning_amber_rounded,
                                    color: error,
                                    texto:
                                        'Bajas tardías: '
                                        '${partido.bajasTardias.map((usuario) => usuario.nombre).join(', ')}',
                                  ),
                              ],
                              menu: _menuAcciones(partido),
                              acciones: _construirAcciones(partido),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
  }
}
