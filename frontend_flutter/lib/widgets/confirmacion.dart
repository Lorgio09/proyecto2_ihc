import 'package:flutter/material.dart';

/// Una confirmación honesta (Tarea 10): dice qué va a pasar, el botón
/// nombra la acción en vez de "Sí"/"No", y ambos botones tienen el mismo tamaño
/// y peso para que ninguna opción se imponga. Sin culpa, sin pasos extra.
///
/// Devuelve true solo cuando la persona confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required List<String> consecuencias,
  required String textoConfirmar,
  required Key keyConfirmar,
  String textoCancelar = 'Cancelar',
  Key keyCancelar = const Key('cancelar-confirmacion'),
  bool destructiva = false,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (contexto) {
      final colores = Theme.of(contexto).colorScheme;
      return AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final punto in consecuencias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: consecuencias.length == 1
                      ? Text(punto)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(punto)),
                          ],
                        ),
                ),
            ],
          ),
        ),
        actions: [
          // IntrinsicHeight + stretch mantienen iguales ambos botones aunque
          // una etiqueta pase a dos líneas en un teléfono angosto.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: keyCancelar,
                    onPressed: () => Navigator.of(contexto).pop(false),
                    child: Text(textoCancelar, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: keyConfirmar,
                    style: destructiva
                        ? FilledButton.styleFrom(
                            backgroundColor: colores.error,
                            foregroundColor: colores.onError,
                          )
                        : null,
                    onPressed: () => Navigator.of(contexto).pop(true),
                    child: Text(textoConfirmar, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  return confirmado == true;
}
