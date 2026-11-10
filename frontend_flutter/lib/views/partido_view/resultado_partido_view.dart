import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../models/validacion.dart';
import '../../services/partido.dart';
import '../../widgets/ayuda.dart';
import '../../widgets/mensaje.dart';

/// Result validation of one match: teams, rival captain, score and history.
///
/// What each person can do depends on their role, which the API reports:
/// the organizer proposes teams and registers the score; the rival captain
/// accepts the teams and confirms or disputes the score.
class ResultadoPartidoView extends StatefulWidget {
  const ResultadoPartidoView({
    super.key,
    required this.partidoId,
    this.partidoService,
  });

  final int partidoId;
  final PartidoService? partidoService;

  @override
  State<ResultadoPartidoView> createState() => _ResultadoPartidoViewState();
}

class _ResultadoPartidoViewState extends State<ResultadoPartidoView> {
  late final PartidoService servicio;
  Validacion? validacion;
  String? mensajeError;
  bool enviando = false;

  // Team proposal form (organizer).
  final equipoB = <int>{};
  int? capitanId;

  // Score form (organizer).
  final golesAController = TextEditingController();
  final golesBController = TextEditingController();

  @override
  void initState() {
    super.initState();
    servicio = widget.partidoService ?? PartidoService();
    cargar();
  }

  @override
  void dispose() {
    golesAController.dispose();
    golesBController.dispose();
    super.dispose();
  }

  void _mostrar(Validacion datos) {
    setState(() {
      validacion = datos;
      mensajeError = null;
      equipoB
        ..clear()
        ..addAll(datos.equipoB.map((usuario) => usuario.id));
      capitanId = datos.capitanRival?.id;
    });
  }

  Future<void> cargar() async {
    try {
      _mostrar(await servicio.obtenerValidacion(widget.partidoId));
    } catch (error) {
      if (mounted) setState(() => mensajeError = error.toString());
    }
  }

  Future<void> _ejecutar(
    Future<Validacion> Function() accion,
    String aviso,
  ) async {
    setState(() => enviando = true);
    try {
      final datos = await accion();
      if (!mounted) return;
      _mostrar(datos);
      golesAController.clear();
      golesBController.clear();
      mostrarMensaje(context, aviso);
    } catch (error) {
      if (mounted) mostrarMensaje(context, error.toString());
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  void proponerEquipos() {
    final capitan = capitanId;
    if (equipoB.isEmpty || capitan == null || !equipoB.contains(capitan)) {
      mostrarMensaje(
        context,
        'Elige el equipo rival y un capitán que sea parte de él',
      );
      return;
    }
    _ejecutar(
      () => servicio.proponerEquipos(
        widget.partidoId,
        equipoB: equipoB.toList(),
        capitanId: capitan,
      ),
      'Equipos propuestos. Falta que el capitán los acepte',
    );
  }

  void registrarMarcador() {
    final golesA = int.tryParse(golesAController.text.trim());
    final golesB = int.tryParse(golesBController.text.trim());
    if (golesA == null || golesB == null || golesA < 0 || golesB < 0) {
      mostrarMensaje(context, 'Escribe los goles de los dos equipos');
      return;
    }
    _ejecutar(
      () => servicio.registrarResultado(widget.partidoId, golesA, golesB),
      'Marcador enviado al capitán rival para validar',
    );
  }

  Future<void> disputar() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoDisputa(),
    );
    if (motivo == null) return;
    if (motivo.trim().isEmpty) {
      if (mounted) mostrarMensaje(context, 'Escribe el motivo de la disputa');
      return;
    }
    await _ejecutar(
      () => servicio.disputarResultado(widget.partidoId, motivo.trim()),
      'Disputa enviada al organizador',
    );
  }

  String _fecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Widget _seccion(String titulo, List<Widget> hijos, {Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _resultadoDefinitivo(Validacion datos) {
    final definitivo = datos.resultadoDefinitivo;
    return _seccion(
      'Resultado definitivo',
      key: const Key('seccion-resultado-definitivo'),
      [
        Text(
          definitivo == null
              ? 'Todavía no hay un resultado definitivo'
              : 'Equipo A ${definitivo.$1} - ${definitivo.$2} Equipo B',
          style: definitivo == null
              ? null
              : Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(datos.estadoTexto, key: const Key('estado-validacion')),
      ],
    );
  }

  String _nombres(List<UsuarioPartido> usuarios, UsuarioPartido? capitan) {
    if (usuarios.isEmpty) return 'Sin jugadores';
    return usuarios
        .map(
          (usuario) => usuario.id == capitan?.id
              ? '${usuario.nombre} (capitán)'
              : usuario.nombre,
        )
        .join(', ');
  }

  Widget _equipos(Validacion datos) {
    return _seccion('Equipos', [
      Text(
        'Equipo A (organiza ${datos.organizador.nombre}): '
        '${_nombres(datos.equipoA, null)}',
      ),
      const SizedBox(height: 4),
      Text('Equipo B (rival): ${_nombres(datos.equipoB, datos.capitanRival)}'),
      if (datos.capitanRival != null) ...[
        const SizedBox(height: 4),
        Text(
          datos.equiposAceptados
              ? 'El capitán aceptó los equipos'
              : 'El capitán todavía no aceptó los equipos',
        ),
      ],
    ]);
  }

  Widget _formularioEquipos(Validacion datos) {
    final candidatosCapitan = datos.titulares
        .where((usuario) => equipoB.contains(usuario.id))
        .toList();
    return _seccion('Proponer equipos', [
      const Text('Marca quiénes juegan en el equipo rival (B).'),
      for (final usuario in datos.titulares)
        CheckboxListTile(
          key: Key('equipo-b-${usuario.nombre}'),
          contentPadding: EdgeInsets.zero,
          title: Text(usuario.nombre),
          value: equipoB.contains(usuario.id),
          onChanged: enviando
              ? null
              : (marcado) => setState(() {
                  if (marcado == true) {
                    equipoB.add(usuario.id);
                  } else {
                    equipoB.remove(usuario.id);
                    if (capitanId == usuario.id) capitanId = null;
                  }
                }),
        ),
      const SizedBox(height: 8),
      const Text('Capitán rival:'),
      if (candidatosCapitan.isEmpty)
        const Text('Primero marca al menos un jugador del equipo rival')
      else
        Wrap(
          spacing: 8,
          children: [
            for (final usuario in candidatosCapitan)
              ChoiceChip(
                key: Key('capitan-${usuario.nombre}'),
                label: Text('Capitán: ${usuario.nombre}'),
                selected: capitanId == usuario.id,
                onSelected: enviando
                    ? null
                    : (_) => setState(() => capitanId = usuario.id),
              ),
          ],
        ),
      const SizedBox(height: 12),
      ElevatedButton(
        key: const Key('boton-proponer-equipos'),
        onPressed: enviando ? null : proponerEquipos,
        child: Text(
          datos.capitanRival == null ? 'Proponer equipos' : 'Cambiar equipos',
        ),
      ),
    ]);
  }

  Widget _formularioMarcador(Validacion datos) {
    final esCorreccion = datos.estado == 'resultado_disputado';
    return _seccion(
      esCorreccion ? 'Corregir el marcador' : 'Registrar el marcador',
      [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-goles-a'),
                controller: golesAController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Goles equipo A'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('campo-goles-b'),
                controller: golesBController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Goles equipo B'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('boton-registrar-marcador'),
          onPressed: enviando ? null : registrarMarcador,
          child: Text(
            esCorreccion ? 'Registrar corrección' : 'Registrar marcador',
          ),
        ),
      ],
    );
  }

  Widget _validarMarcador(Validacion datos) {
    final pendiente = datos.resultados.first;
    return _seccion('Validar el marcador', [
      Text(
        'El organizador registró: Equipo A ${pendiente.golesA} - '
        '${pendiente.golesB} Equipo B',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            key: const Key('boton-confirmar-resultado'),
            onPressed: enviando
                ? null
                : () => _ejecutar(
                    () => servicio.confirmarResultado(widget.partidoId),
                    'Resultado confirmado',
                  ),
            child: const Text('Confirmar resultado'),
          ),
          OutlinedButton(
            key: const Key('boton-disputar-resultado'),
            onPressed: enviando ? null : disputar,
            child: const Text('Disputar'),
          ),
        ],
      ),
    ]);
  }

  Widget _aceptarEquipos() {
    return _seccion('Aceptar equipos', [
      const Text('El organizador te propuso como capitán del equipo rival.'),
      const SizedBox(height: 12),
      ElevatedButton(
        key: const Key('boton-aceptar-equipos'),
        onPressed: enviando
            ? null
            : () => _ejecutar(
                () => servicio.aceptarEquipos(widget.partidoId),
                'Aceptaste los equipos',
              ),
        child: const Text('Aceptar equipos'),
      ),
    ]);
  }

  Widget _historial(Validacion datos) {
    return _seccion(
      'Historial del marcador',
      key: const Key('seccion-historial'),
      [
        if (datos.resultados.isEmpty)
          const Text('Todavía no se registró ningún marcador')
        else
          for (final version in datos.resultados)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versión ${version.version}: '
                    '${version.golesA} - ${version.golesB} · '
                    '${version.estadoTexto}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (version.motivoDisputa != null)
                    Text('Motivo: ${version.motivoDisputa}'),
                  Text(
                    'Registrado: ${_fecha(version.registradoEn)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ],
    );
  }

  List<Widget> _acciones(Validacion datos) {
    final sinResultados = datos.resultados.isEmpty;
    return [
      if (datos.esOrganizador && sinResultados && !datos.partidoJugado)
        _formularioEquipos(datos),
      if (datos.esCapitan &&
          datos.estado == 'equipos_propuestos' &&
          !datos.partidoJugado)
        _aceptarEquipos(),
      if (datos.esOrganizador &&
          datos.partidoJugado &&
          (datos.estado == 'equipos_aceptados' ||
              datos.estado == 'resultado_disputado'))
        _formularioMarcador(datos),
      if (datos.esCapitan && datos.estado == 'resultado_pendiente')
        _validarMarcador(datos),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final datos = validacion;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del partido'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.help_outline),
            onPressed: () => mostrarAyuda(
              context,
              '¿Cómo se valida el resultado?',
              '1. El organizador propone los equipos y un capitán rival.\n'
                  '2. El capitán acepta los equipos antes del partido.\n'
                  '3. Al terminar, el organizador registra el marcador.\n'
                  '4. El capitán lo confirma o lo disputa con un motivo.\n'
                  '5. Si hay disputa, el organizador lo corrige y el capitán '
                  'vuelve a validarlo.\n\n'
                  'Solo el marcador confirmado es definitivo. El historial '
                  'guarda todas las versiones.',
            ),
          ),
        ],
      ),
      body: datos == null
          ? Center(
              child: mensajeError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mensajeError!),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: cargar,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  ListTile(
                    title: Text(
                      datos.nombre,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(
                      '${datos.ubicacion} · ${_fecha(datos.fecha)}',
                    ),
                  ),
                  _resultadoDefinitivo(datos),
                  ..._acciones(datos),
                  _equipos(datos),
                  _historial(datos),
                ],
              ),
            ),
    );
  }
}

/// Owns its text controller so it outlives the dialog's closing animation.
class _DialogoDisputa extends StatefulWidget {
  const _DialogoDisputa();

  @override
  State<_DialogoDisputa> createState() => _DialogoDisputaState();
}

class _DialogoDisputaState extends State<_DialogoDisputa> {
  final motivoController = TextEditingController();

  @override
  void dispose() {
    motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disputar el marcador'),
      content: TextField(
        key: const Key('campo-motivo-disputa'),
        controller: motivoController,
        autofocus: true,
        maxLength: 255,
        decoration: const InputDecoration(
          labelText: 'Motivo',
          hintText: 'Ej.: el segundo gol fue en fuera de juego',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('enviar-disputa'),
          onPressed: () => Navigator.pop(context, motivoController.text),
          child: const Text('Enviar disputa'),
        ),
      ],
    );
  }
}
