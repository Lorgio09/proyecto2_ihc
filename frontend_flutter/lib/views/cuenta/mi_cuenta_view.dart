import 'dart:convert';

import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../services/cuenta_service.dart';
import '../../widgets/confirmacion.dart';
import '../../widgets/mensaje.dart';
import '../autenticacion/login_view.dart';

/// "Mi cuenta": everything UniSport keeps about the person, the way to take
/// it with them and the way to leave.
class MiCuentaView extends StatefulWidget {
  const MiCuentaView({super.key, this.cuentaService, this.alSalir});

  final CuentaService? cuentaService;

  /// Where to go once the account is gone; the login screen by default.
  final void Function(BuildContext context)? alSalir;

  @override
  State<MiCuentaView> createState() => _MiCuentaViewState();
}

class _MiCuentaViewState extends State<MiCuentaView> {
  late final CuentaService servicio;
  Map<String, dynamic>? datos;
  String? error;
  bool descargando = false;
  bool eliminando = false;

  static const nombreArchivo = 'unisport-mis-datos.json';

  @override
  void initState() {
    super.initState();
    servicio = widget.cuentaService ?? CuentaService();
    // Start of the "download my data" funnel.
    servicio.registrarEvento('mis_datos_vistos');
    cargar();
  }

  Future<void> cargar() async {
    setState(() => error = null);
    try {
      final resultado = await servicio.misDatos();
      if (mounted) setState(() => datos = resultado);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudieron cargar tus datos');
    }
  }

  Future<void> descargar() async {
    final contenido = datos;
    if (contenido == null) return;
    setState(() => descargando = true);
    try {
      await servicio.guardarEnDescargas(
        nombreArchivo,
        const JsonEncoder.withIndent('  ').convert(contenido),
      );
      servicio.registrarEvento('mis_datos_descargados');
      if (mounted) {
        mostrarMensaje(
          context,
          'Tus datos se guardaron en Descargas/$nombreArchivo',
        );
      }
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo guardar el archivo');
    } finally {
      if (mounted) setState(() => descargando = false);
    }
  }

  /// Leaving is as short as signing up: one button, one honest confirmation.
  /// When UniSport's rule stops it, say why and what to do instead.
  Future<void> eliminar() async {
    servicio.registrarEvento('eliminacion_iniciada');
    setState(() => eliminando = true);
    try {
      final previa = await servicio.antesDeEliminar();
      if (!mounted) return;
      final bloqueos = (previa['bloqueos'] as List)
          .cast<Map<String, dynamic>>();
      if (bloqueos.isNotEmpty) {
        await _mostrarBloqueo(bloqueos);
        return;
      }
      final confirmado = await _confirmar(
        previa['consecuencias'] as Map<String, dynamic>,
      );
      if (!confirmado || !mounted) return;

      await servicio.eliminarCuenta();
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      (widget.alSalir ?? _irAlLogin)(context);
      mensajero.showSnackBar(
        const SnackBar(content: Text('Tu cuenta fue eliminada')),
      );
    } on CuentaBloqueada catch (bloqueo) {
      // Something changed between the check and the confirmation; the
      // backend already recorded this block.
      if (mounted) await _mostrarBloqueo(bloqueo.bloqueos, registrar: false);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(
          context,
          'No se pudo eliminar la cuenta. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => eliminando = false);
    }
  }

  void _irAlLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  Future<void> _mostrarBloqueo(
    List<Map<String, dynamic>> bloqueos, {
    bool registrar = true,
  }) async {
    if (registrar) {
      for (final bloqueo in bloqueos) {
        servicio.registrarEvento(
          'tarea_fallida',
          props: {
            'flujo': 'eliminar_cuenta',
            'motivo': bloqueo['codigo'] as String,
          },
        );
      }
    }
    await showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: const Text('Todavía no puedes eliminar tu cuenta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final bloqueo in bloqueos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(bloqueo['mensaje'] as String),
                ),
              const Text('Tu cuenta y tus datos siguen igual.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('cerrar-bloqueo'),
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmar(Map<String, dynamic> consecuencias) {
    final futuros = consecuencias['partidos_futuros'] as int;
    final ascensos = consecuencias['ascensos_de_suplentes'] as int;
    final organizados = consecuencias['partidos_organizados_eliminados'] as int;
    final resultados = consecuencias['resultados_anonimizados'] as int;
    String partidos(int n) => n == 1 ? '1 partido' : '$n partidos';
    String plural(int n) => n == 1 ? '' : 'n';

    final puntos = [
      'Se borran tu nombre, tu correo, tu teléfono y tu historial.',
      if (futuros > 0)
        'Sales de ${partidos(futuros)} que aún no se juega${plural(futuros)}.'
            '${ascensos > 0 ? ' Tu lugar de titular pasa al primer suplente.' : ''}',
      if (organizados > 0)
        'Se elimina${plural(organizados)} ${partidos(organizados)} '
            'que organizas.',
      if (resultados > 0)
        'Los resultados confirmados de ${partidos(resultados)} se conservan, '
            'pero aparecerás como "Usuario eliminado".',
      'Ya no podrás iniciar sesión con esta cuenta. No se puede deshacer.',
    ];

    return confirmarAccion(
      context,
      titulo: '¿Eliminar tu cuenta?',
      consecuencias: puntos,
      textoConfirmar: 'Eliminar cuenta',
      keyConfirmar: const Key('confirmar-eliminar-cuenta'),
      keyCancelar: const Key('cancelar-eliminar-cuenta'),
      destructiva: true,
    );
  }

  Widget _seccionEliminar(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eliminar mi cuenta', style: textos.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Borra tu cuenta y tus datos. Antes de confirmar verás qué '
              'pasa con tus partidos.',
              style: textos.bodyMedium?.copyWith(color: Blueslate),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('boton-eliminar-cuenta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: eliminando ? null : eliminar,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar mi cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _cantidad(String clave) => (datos?[clave] as List?)?.length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: cargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : datos == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _seccionDatos(context),
                const SizedBox(height: 16),
                _seccionEliminar(context),
              ],
            ),
    );
  }

  Widget _seccionDatos(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cuenta = datos!['cuenta'] as Map<String, dynamic>;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis datos', style: textos.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Esto es todo lo que UniSport guarda sobre ti.',
              style: textos.bodyMedium?.copyWith(color: Blueslate),
            ),
            const SizedBox(height: 12),
            _Fila(
              icono: Icons.person_outline,
              texto: cuenta['nombre'] as String,
            ),
            _Fila(icono: Icons.mail_outline, texto: cuenta['email'] as String),
            _Fila(
              icono: Icons.phone_outlined,
              texto: (cuenta['telefono'] as String?) ?? 'Sin teléfono',
            ),
            const Divider(height: 24),
            _Fila(
              icono: Icons.event_note,
              texto:
                  'Partidos que organizas: ${_cantidad('partidos_organizados')}',
            ),
            _Fila(
              icono: Icons.group_outlined,
              texto:
                  'Partidos en los que participas: ${_cantidad('participaciones')}',
            ),
            _Fila(
              icono: Icons.history,
              texto: 'Movimientos en tu historial: ${_cantidad('historial')}',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('boton-descargar-datos'),
                onPressed: descargando ? null : descargar,
                icon: descargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Descargar mis datos (JSON)'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Se guarda como $nombreArchivo en la carpeta Descargas.',
              style: textos.bodySmall?.copyWith(color: Blueslate),
            ),
            const Divider(height: 24),
            // Transparency: the analytics exist, and they are not about you.
            Text(
              'Para mejorar la app, UniSport cuenta acciones como "se unió '
              'a un partido" sin tu nombre, tu correo ni ningún dato que te '
              'identifique. Por eso no aparecen en tus datos.',
              key: const Key('aviso-analitica'),
              style: textos.bodySmall?.copyWith(color: Blueslate),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 20, color: Blueslate),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
