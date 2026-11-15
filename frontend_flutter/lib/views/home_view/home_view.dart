import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../widgets/ayuda.dart';
import '../autenticacion/cambiar_contraseña.dart';
import '../autenticacion/login_view.dart';
import '../partido_view/explorar_partidos_view.dart';
import '../partido_view/list_partidoview.dart';
import '../partido_view/historial_partidos_view.dart';
import '../../widgets/marca.dart';
import '../cuenta/mi_cuenta_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.user, required this.authService});

  final Usuario user;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              mostrarAyuda(
                context,
                '¿Cómo usar UniSport?',
                'En Mis partidos puedes crear y administrar tus partidos.\n\n'
                    'En Explorar partidos puedes buscar partidos creados por '
                    'otros usuarios y unirte si todavía tienen cupos.',
              );
            },
          ),
          IconButton(
            key: const Key('boton-mi-cuenta'),
            tooltip: 'Mi cuenta',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MiCuentaView())),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Cambiar contraseña',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => cambiarContraView(authService: authService),
              ),
            ),
            icon: const Icon(Icons.key),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await authService.logout();
              if (!context.mounted) return;
              await Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginView()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MarcaUniSport(compacta: true),
                const SizedBox(height: 24),
                Text(
                  '¡Bienvenido, ${user.nombre}!',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: Jetblack, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: Blueslate),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _Acceso(
                  key: const Key('boton-mis-partidos'),
                  icono: Icons.event_note,
                  titulo: 'Mis partidos',
                  descripcion: 'Los que organizas y a los que te uniste',
                  alPresionar: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ListPartidoView(usuario: user),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Acceso(
                  key: const Key('boton-explorar-partidos'),
                  icono: Icons.travel_explore,
                  titulo: 'Explorar partidos',
                  descripcion: 'Encuentra un partido con cupo y únete',
                  alPresionar: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExplorarPartidosView(usuario: user),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Acceso(
                  key: const Key('boton-mi-historial'),
                  icono: Icons.history,
                  titulo: 'Mi historial',
                  descripcion: 'Los partidos en los que participaste',
                  alPresionar: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistorialPartidosView(usuario: user),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A main entry of the home screen: icon, name and what it is for, all of
/// it one big touch target.
class _Acceso extends StatelessWidget {
  const _Acceso({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.alPresionar,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Semantics(
        button: true,
        container: true,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alPresionar,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CoralAccesible.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icono, color: CoralAccesible),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: textos.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          descripcion,
                          style: textos.bodySmall?.copyWith(color: Blueslate),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Blueslate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
