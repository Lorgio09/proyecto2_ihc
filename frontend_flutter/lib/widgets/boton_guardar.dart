import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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
      height: 48,
      child: Material(
        color: UniColores.primario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UniRadio.pildora),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(UniRadio.pildora),
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
                    style: const TextStyle(color: UniColores.sobreColor),
                  ),
          ),
        ),
      ),
    );
  }
}
