import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../services/auth_service.dart';
import '../../widgets/boton_guardar.dart';
import '../../widgets/input.dart';
import 'login_view.dart';

class cambiarContraView extends StatefulWidget {
  const cambiarContraView({
    super.key,
    this.modoRecuperacion = false,
    this.correoRecuperacion,
    this.tokenRecuperacion,
    this.authService,
  });

  final bool modoRecuperacion;
  final String? correoRecuperacion;
  final String? tokenRecuperacion;
  final AuthService? authService;

  @override
  State<cambiarContraView> createState() => _cambiarContraViewState();
}

class _cambiarContraViewState extends State<cambiarContraView> {
  final _contrasenaActualControlador = TextEditingController();
  final _contrasenaNuevaControlador = TextEditingController();
  final _contrasenaCofirmarControlador = TextEditingController();
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _estaCargando = false;

  @override
  void dispose() {
    _contrasenaActualControlador.dispose();
    _contrasenaNuevaControlador.dispose();
    _contrasenaCofirmarControlador.dispose();
    super.dispose();
  }

  Future<void> _cambiarContrasena() async {
    final contrasenaActual = _contrasenaActualControlador.text;
    final contrasenaNueva = _contrasenaNuevaControlador.text;
    final contrasenaConfirmar = _contrasenaCofirmarControlador.text;

    if ((!widget.modoRecuperacion && contrasenaActual.isEmpty) ||
        contrasenaNueva.isEmpty ||
        contrasenaConfirmar.isEmpty) {
      _mostrarMensaje('Completa los campos obligatorios.');
      return;
    }

    if (contrasenaNueva.length < 8) {
      _mostrarMensaje('La nueva contraseña debe tener al menos 8 caracteres.');
      return;
    }

    if (contrasenaNueva != contrasenaConfirmar) {
      _mostrarMensaje('Las contraseñas nuevas no coinciden.');
      return;
    }

    if (!widget.modoRecuperacion && contrasenaNueva == contrasenaActual) {
      _mostrarMensaje('La nueva contraseña debe ser distinta a la actual.');
      return;
    }

    setState(() => _estaCargando = true);
    try {
      if (widget.modoRecuperacion) {
        if (widget.tokenRecuperacion == null) {
          _mostrarMensaje('El token de recuperación no es válido.');
          return;
        }
        await _authService.cambiarPassword(
          widget.tokenRecuperacion!,
          contrasenaNueva,
        );
      } else {
        await _authService.cambiarPasswordAutenticado(
          contrasenaActual,
          contrasenaNueva,
        );
      }
      if (!mounted) return;
      _mostrarMensaje('Contraseña actualizada correctamente.');
      if (widget.modoRecuperacion) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (_) => false,
        );
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (error) {
      _mostrarMensaje(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _estaCargando = false);
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
      appBar: AppBar(
        title: Text(
          widget.modoRecuperacion
              ? 'Restablecer contraseña'
              : 'Cambiar contraseña',
        ),
      ),
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
                      if (widget.modoRecuperacion)
                        Text('Cuenta: ${widget.correoRecuperacion ?? ''}')
                      else
                        Input(
                          etiqueta: 'Contraseña actual',
                          controlador: _contrasenaActualControlador,
                          placeholder: '••••••••',
                          ocultarTexto: true,
                        ),
                      Input(
                        etiqueta: 'Nueva contraseña',
                        controlador: _contrasenaNuevaControlador,
                        placeholder: '••••••••',
                        ocultarTexto: true,
                      ),
                      Input(
                        etiqueta: 'Confirmar nueva contraseña',
                        controlador: _contrasenaCofirmarControlador,
                        placeholder: '••••••••',
                        ocultarTexto: true,
                      ),
                      const SizedBox(height: 33),
                      Center(
                        child: BotonGuardar(
                          texto: widget.modoRecuperacion
                              ? 'Restablecer contraseña'
                              : 'Cambiar contraseña',
                          estaCargando: _estaCargando,
                          alPresionar: _cambiarContrasena,
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
