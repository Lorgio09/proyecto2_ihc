import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../services/auth_service.dart';
import '../../widgets/boton_guardar.dart';
import '../../widgets/input.dart';
import '../home_view/home_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nombre_controlador = TextEditingController();
  final _email_controlador = TextEditingController();
  final _password_controlador = TextEditingController();
  final _telefono_controlador = TextEditingController();
  final _auth_service = AuthService();
  bool _esta_cargando = false;

  @override
  void dispose() {
    _nombre_controlador.dispose();
    _email_controlador.dispose();
    _password_controlador.dispose();
    _telefono_controlador.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final nombre = _nombre_controlador.text.trim();
    final email = _email_controlador.text.trim();
    final password = _password_controlador.text;
    final telefono = _telefono_controlador.text.trim();

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      _mostrarMensaje('Completa los campos obligatorios.');
      return;
    }

    setState(() => _esta_cargando = true);

    try {
      final user = await _auth_service.registro(
        nombre,
        email,
        password,
        telefono.isEmpty ? null : telefono,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeView(user: user, authService: _auth_service),
        ),
      );
    } catch (error) {
      _mostrarMensaje(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _esta_cargando = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    spacing: 16,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Input(
                        etiqueta: 'Nombre',
                        controlador: _nombre_controlador,
                        placeholder: 'Tu nombre',
                      ),

                      Input(
                        etiqueta: 'Email',
                        controlador: _email_controlador,
                        placeholder: 'correo@ejemplo.com',
                      ),

                      Input(
                        etiqueta: 'Contraseña',
                        controlador: _password_controlador,
                        placeholder: '••••••••',
                        ocultarTexto: true,
                      ),

                      Input(
                        etiqueta: 'Teléfono',
                        controlador: _telefono_controlador,
                        placeholder: '00000000',
                      ),
                      const SizedBox(height: 33),
                      Center(
                        child: BotonGuardar(
                          texto: 'Registrarme',
                          estaCargando: _esta_cargando,
                          alPresionar: _registrar,
                        ),
                      ),

                      Center(
                        child: Wrap(
                          children: [
                            Text('Ya tienes Cuenta? '),
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text('Inicia Sesion'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
