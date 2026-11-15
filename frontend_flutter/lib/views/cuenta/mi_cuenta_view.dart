import 'dart:convert';

import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../services/cuenta_service.dart';
import '../../widgets/mensaje.dart';

/// "Mi cuenta": everything UniSport keeps about the person, and the way to
/// take it with them.
class MiCuentaView extends StatefulWidget {
  const MiCuentaView({super.key, this.cuentaService});

  final CuentaService? cuentaService;

  @override
  State<MiCuentaView> createState() => _MiCuentaViewState();
}

class _MiCuentaViewState extends State<MiCuentaView> {
  late final CuentaService servicio;
  Map<String, dynamic>? datos;
  String? error;
  bool descargando = false;

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
              children: [_seccionDatos(context)],
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
