import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../models/usuario.dart';
import '../../services/partido.dart';
import '../../widgets/ayuda.dart';
import '../../widgets/mensaje.dart';
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

  Widget panelFiltros() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: busquedaController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o ubicación',
                hintText: 'Ej. Oriente o Cancha central',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: estadoFiltro,
              decoration: const InputDecoration(
                labelText: 'Filtrar por estado',
                prefixIcon: Icon(Icons.filter_list),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: 'Aplicar la búsqueda y el estado seleccionado',
                child: OutlinedButton.icon(
                  onPressed: hayFiltrosPendientes ? aplicarFiltros : null,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar partidos'),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Borrar búsqueda y estado seleccionado',
                child: TextButton(
                  onPressed: hayFiltrosActivos ? limpiarFiltros : null,
                  child: const Text('Limpiar filtros'),
                ),
              ),
            ),
          ],
        ),
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
      return;
    }

    final datos = await showDialog<DatosReprogramacion>(
      context: context,
      builder: (context) => ReprogramarPartidoDialog(partido: partido),
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

  Widget _construirAcciones(Partido partido) {
    final estado = partido.estado.trim().toLowerCase();
    final estaEliminando = partidoEliminandoId == partido.id;
    final estaCompletando = partidoCompletandoId == partido.id;
    final estaReabriendo = partidoReabriendoId == partido.id;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (estado == 'cupos abiertos')
          ElevatedButton(
            key: const Key('boton-completar-partido'),
            onPressed: estaCompletando ? null : () => completarEquipo(partido),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFFB45309,
              ), // 5.0:1 against white text
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
                : const Text('Completar equipo'),
          ),
        if (estado == 'equipo completo')
          ElevatedButton(
            key: const Key('boton-reabrir-partido'),
            onPressed: estaReabriendo ? null : () => reabrirEquipo(partido),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            child: estaReabriendo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Reabrir equipo'),
          ),
        OutlinedButton(
          key: const Key('boton-reprogramar-partido'),
          onPressed: () => reprogramarPartido(partido),
          child: const Text('Reprogramar'),
        ),
        IconButton(
          key: const Key('boton-resultado-partido'),
          tooltip: 'Resultado del partido',
          onPressed: () => abrirResultado(partido),
          icon: const Icon(Icons.scoreboard_outlined),
        ),
        IconButton(
          tooltip: 'Editar partido',
          onPressed: () => abrirFormulario(partido: partido),
          icon: const Icon(Icons.edit),
        ),
        IconButton(
          tooltip: 'Eliminar partido',
          onPressed: estaEliminando ? null : () => borrarPartido(partido),
          icon: estaEliminando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete),
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
          ? FloatingActionButton(
              tooltip: 'Nuevo partido',
              onPressed: guardandoPartido ? null : () => abrirFormulario(),
              child: const Icon(Icons.add),
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
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('No tienes partidos todavía'),
                            SizedBox(height: 8),
                            Text(
                              'Pulsa el botón + para crear tu primer partido',
                            ),
                          ],
                        ),
                      )
                    : partidosVisibles.isEmpty
                    ? const Center(
                        child: Text(
                          'No encontramos partidos con estos filtros',
                          textAlign: TextAlign.center,
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

                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                title: Text(partido.nombre),
                                subtitle: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Deporte: ${partido.deporteTexto}'),
                                    Text('Ubicación: ${partido.ubicacion}'),
                                    Text('Fecha: ${fechaTexto(partido.fecha)}'),
                                    Text(
                                      'Cupos: ${partido.cantidadParticipantes}/'
                                      '${partido.cantidadJugadores}',
                                    ),
                                    Text(
                                      'Duración: '
                                      '${partido.tiempoMin ?? 'No definida'}',
                                    ),
                                    Text('Estado: ${partido.estadoTexto}'),
                                    if (partido.motivoReprogramacion != null)
                                      Text(
                                        'Reprogramado: '
                                        '${partido.motivoReprogramacion}',
                                      ),
                                    if (partido.tieneRespuestasPendientes)
                                      Text(
                                        'Esperando respuesta de: '
                                        '${partido.pendientesConfirmar.map((usuario) => usuario.nombre).join(', ')}',
                                      ),
                                    if (partido.bajasTardias.isNotEmpty)
                                      Text(
                                        'Bajas tardías: '
                                        '${partido.bajasTardias.map((usuario) => usuario.nombre).join(', ')}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                    Text(
                                      'Participantes: ${partido.cantidadParticipantes}',
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
                                    if (estaExpandido &&
                                        partido.suplentes.isNotEmpty)
                                      Text(
                                        'Suplentes: '
                                        '${partido.suplentes.map((suplente) => suplente.nombre).join(', ')}',
                                      ),
                                    _construirAcciones(partido),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
  }
}
