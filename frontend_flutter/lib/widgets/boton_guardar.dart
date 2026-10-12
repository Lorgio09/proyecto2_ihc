import 'package:flutter/material.dart';

import '../consts/color.dart';

class BotonGuardar extends StatelessWidget {
  const BotonGuardar({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.estaCargando = false,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final bool estaCargando;

  @override
  Widget build(BuildContext context) {
    final habilitado = alPresionar != null && !estaCargando;

    return SizedBox(
      width: 138,
      height: 46,
      child: Material(
        color: CoralgLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: habilitado ? alPresionar : null,
          child: Center(
            child: estaCargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: white),
                  ),
          ),
        ),
      ),
    );
  }
}
