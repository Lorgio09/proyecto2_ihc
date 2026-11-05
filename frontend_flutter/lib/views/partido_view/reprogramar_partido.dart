import 'package:flutter/material.dart';

import '../../models/partido.dart';

/// Lo que el organizador eligió al reprogramar. Solo trae lo que cambió.
class DatosReprogramacion {
  final DateTime? fecha;
  final String? ubicacion;
  final String motivo;

  const DatosReprogramacion({this.fecha, this.ubicacion, required this.motivo});
}

/// Diálogo para cambiar fecha, hora o lugar de un partido con un motivo.
class ReprogramarPartidoDialog extends StatefulWidget {
  const ReprogramarPartidoDialog({super.key, required this.partido});

  final Partido partido;

  @override
  State<ReprogramarPartidoDialog> createState() =>
      _ReprogramarPartidoDialogState();
}

class _ReprogramarPartidoDialogState extends State<ReprogramarPartidoDialog> {
  late final TextEditingController ubicacionController;
  final motivoController = TextEditingController();
  DateTime? nuevaFecha;
  String? error;

  @override
  void initState() {
    super.initState();
    ubicacionController = TextEditingController(text: widget.partido.ubicacion);
  }

  @override
  void dispose() {
    ubicacionController.dispose();
    motivoController.dispose();
    super.dispose();
  }

  String fechaTexto(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Future<void> elegirFecha() async {
    final base = nuevaFecha ?? widget.partido.fecha ?? DateTime.now();
    final hoy = DateTime.now();
    final primera = DateTime(hoy.year, hoy.month, hoy.day);
    final dia = await showDatePicker(
      context: context,
      firstDate: primera,
      lastDate: DateTime(2035),
      initialDate: base.isBefore(primera) ? primera : base,
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (hora == null) return;

    setState(() {
      nuevaFecha = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
      error = null;
    });
  }

  void guardar() {
    final ubicacion = ubicacionController.text.trim();
    final motivo = motivoController.text.trim();
    final cambiaFecha = nuevaFecha != null && nuevaFecha != widget.partido.fecha;
    final cambiaLugar = ubicacion.isNotEmpty && ubicacion != widget.partido.ubicacion;

    if (!cambiaFecha && !cambiaLugar) {
      setState(() => error = 'Cambia la fecha, la hora o el lugar');
      return;
    }
    if (cambiaFecha && !nuevaFecha!.isAfter(DateTime.now())) {
      setState(() => error = 'La nueva fecha debe ser futura');
      return;
    }
    if (motivo.isEmpty) {
      setState(() => error = 'Escribe el motivo del cambio');
      return;
    }

    Navigator.pop(
      context,
      DatosReprogramacion(
        fecha: cambiaFecha ? nuevaFecha : null,
        ubicacion: cambiaLugar ? ubicacion : null,
        motivo: motivo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reprogramar partido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Los titulares tendrán que confirmar si siguen. Mientras '
              'responden conservan su lugar.',
            ),
            const SizedBox(height: 16),
            Text('Fecha actual: ${fechaTexto(widget.partido.fecha)}'),
            Text(
              nuevaFecha == null
                  ? 'Nueva fecha: sin cambios'
                  : 'Nueva fecha: ${fechaTexto(nuevaFecha)}',
            ),
            TextButton(
              key: const Key('boton-elegir-nueva-fecha'),
              onPressed: elegirFecha,
              child: const Text('Elegir nueva fecha y hora'),
            ),
            TextField(
              key: const Key('campo-ubicacion-reprogramacion'),
              controller: ubicacionController,
              decoration: const InputDecoration(labelText: 'Lugar'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('campo-motivo-reprogramacion'),
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo del cambio',
                hintText: 'Ej. la cancha está en mantenimiento',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('confirmar-reprogramar-partido'),
          onPressed: guardar,
          child: const Text('Reprogramar'),
        ),
      ],
    );
  }
}
