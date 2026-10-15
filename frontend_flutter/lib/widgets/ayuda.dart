import 'package:flutter/material.dart';

void mostrarAyuda(
  BuildContext context,
  String titulo,
  String mensaje,
) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}
