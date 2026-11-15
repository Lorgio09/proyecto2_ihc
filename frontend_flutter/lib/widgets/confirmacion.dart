import 'package:flutter/material.dart';

/// An honest confirmation (Tarea 10): it says what will happen, the button
/// names the action instead of "Sí"/"No", and both buttons have the same size
/// and weight so neither choice is pushed. No guilt, no extra steps.
///
/// Returns true only when the person confirms.
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
          // IntrinsicHeight + stretch keep both buttons equal even when one
          // label wraps on a narrow phone.
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
