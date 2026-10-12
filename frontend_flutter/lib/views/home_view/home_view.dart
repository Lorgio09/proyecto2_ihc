import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../widgets/boton_guardar.dart';
import '../autenticacion/cambiar_contraseña.dart';
import '../autenticacion/login_view.dart';
import '../partido_view/list_partidoview.dart';

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
                Image.asset(
                  'assets/icons/futbol.png',
                  width: 144,
                  height: 144,
                  semanticLabel: 'Ilustración de fútbol',
                ),
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
                BotonGuardar(
                  texto: 'Mis partidos',
                  alPresionar: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ListPartidoView()),
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
