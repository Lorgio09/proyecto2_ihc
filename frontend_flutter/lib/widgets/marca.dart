import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Logo, nombre y eslogan de UniSport, dibujados en código para no necesitar un
/// archivo de imagen. [compacta] muestra un logo más pequeño y sin eslogan,
/// para pantallas internas.
class MarcaUniSport extends StatelessWidget {
  const MarcaUniSport({super.key, this.compacta = false});

  final bool compacta;

  static const eslogan = 'Arma tu partido, completa tu equipo.';

  @override
  Widget build(BuildContext context) {
    final tamano = compacta ? 56.0 : 88.0;
    final textos = Theme.of(context).textTheme;

    return Semantics(
      label: 'UniSport. $eslogan',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tamano,
              height: tamano,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [UniColores.primarioClaro, UniColores.primario],
                ),
                borderRadius: BorderRadius.circular(tamano * 0.28),
                boxShadow: [
                  BoxShadow(
                    color: UniColores.primario.withValues(
                      alpha: 0.3,
                    ), // sombra del logo
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.sports_soccer,
                color: UniColores.sobreColor,
                size: tamano * 0.6,
              ),
            ),
            SizedBox(height: compacta ? 8 : 14),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Uni',
                    style: TextStyle(color: UniColores.texto),
                  ),
                  const TextSpan(
                    text: 'Sport',
                    style: TextStyle(color: UniColores.primario),
                  ),
                ],
                style: (compacta ? textos.titleLarge : textos.headlineMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
            ),
            if (!compacta) ...[
              const SizedBox(height: 4),
              Text(
                eslogan,
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(
                  color: UniColores.textoSecundario,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
