import 'package:flutter/material.dart';

import '../../consts/color.dart';
import '../../services/auth_service.dart';
import '../../widgets/boton_guardar.dart';
import '../../widgets/input.dart';
import 'cambiar_contraseña.dart';

class OlvideContrasenaView extends StatefulWidget {
  const OlvideContrasenaView({super.key});

  @override
  State<OlvideContrasenaView> createState() => _OlvideContrasenaViewState();
}

class _OlvideContrasenaViewState extends State<OlvideContrasenaView> {
  final _correoControlador = TextEditingController();
  final _codigoControlador = TextEditingController();
  final _authService = AuthService();
  bool _codigoEnviado = false;
  bool _estaCargando = false;
  String? _tokenRecuperacion;

  @override
  void dispose() {
    _correoControlador.dispose();
    _codigoControlador.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final correo = _correoControlador.text.trim();

    if (!_codigoEnviado) {
      setState(() => _estaCargando = true);
      try {
        _tokenRecuperacion = await _authService.recuperarPassword(correo);
        if (!mounted) return;
        setState(() => _codigoEnviado = true);
        _mostrarMensaje('Código enviado. Usa el código 123456.');
      } catch (error) {
        _mostrarMensaje(error.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _estaCargando = false);
      }
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(_codigoControlador.text.trim())) {
      _mostrarMensaje('Ingresa el codigo de seis dígitos.');
      return;
    }

    if (_codigoControlador.text.trim() != _tokenRecuperacion) {
      _mostrarMensaje('El codigo ingresado no es correcto.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => cambiarContraView(
          modoRecuperacion: true,
          correoRecuperacion: correo,
          tokenRecuperacion: _tokenRecuperacion,
        ),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Center(
                child: Image.asset(
                  'assets/icons/llave.png',
                  width: 166,
                  height: 216,
                  semanticLabel: 'Ilustración de usuario',
                ),
              ),
              Input(
                etiqueta: 'Email',
                controlador: _correoControlador,
                placeholder: 'correo@ejemplo.com',
                soloLectura: _codigoEnviado,
              ),
              if (_codigoEnviado)
                Input(
                  etiqueta: 'Codigo de verificacion',
                  controlador: _codigoControlador,
                  placeholder: '123456',
                ),
              const SizedBox(height: 17),
              Center(
                child: BotonGuardar(
                  texto: _codigoEnviado ? 'Verificar codigo' : 'Continuar',
                  estaCargando: _estaCargando,
                  alPresionar: _continuar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
