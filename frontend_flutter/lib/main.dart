import 'package:flutter/material.dart';

import 'models/usuario.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'views/home_view/home_view.dart';
import 'views/autenticacion/login_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inicio',
      theme: temaPrincipal,
      home: SessionGate(authService: authService),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final AuthService _authService;
  late final Future<Usuario?> _userFuture;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userFuture = _authService.currentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Usuario?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (snapshot.hasError || user == null) return const LoginView();
        return HomeView(user: user, authService: _authService);
      },
    );
  }
}
