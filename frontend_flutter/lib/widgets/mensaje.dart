import 'package:flutter/material.dart';

void mostrarMensaje(BuildContext context, String mensaje) {
  _mostrarSnackBar(context, mensaje);
}

void mostrarMensajeConAccion(
  BuildContext context,
  String mensaje, {
  required String textoAccion,
  required VoidCallback accion,
}) {
  _mostrarSnackBar(
    context,
    mensaje,
    accion: SnackBarAction(label: textoAccion, onPressed: accion),
  );
}

void _mostrarSnackBar(
  BuildContext context,
  String mensaje, {
  SnackBarAction? accion,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje)),
        ],
      ),
      action: accion,
      backgroundColor: Colors.deepOrangeAccent,
    ),
  );
}
