import 'package:flutter/material.dart';

void mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje
            ),
          ),
        ],
      ),

      backgroundColor: Colors.deepOrangeAccent
    ),
  );
}