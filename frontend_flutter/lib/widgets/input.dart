import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class Input extends StatefulWidget {
  const Input({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.placeholder,
    this.soloLectura = false,
    this.ocultarTexto = false,
    this.validator,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final String? placeholder;
  final bool soloLectura;
  final bool ocultarTexto;
  final FormFieldValidator<String>? validator;

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  // A password field starts hidden; the eye lets the person check what they typed.
  late bool _oculto = widget.ocultarTexto;

  @override
  void didUpdateWidget(Input anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.ocultarTexto != widget.ocultarTexto) {
      _oculto = widget.ocultarTexto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.etiqueta, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: TextFormField(
            controller: widget.controlador,
            readOnly: widget.soloLectura,
            style: TextStyle(
              color: widget.soloLectura ? UniColores.texto : null,
            ),
            obscureText: _oculto,
            enableSuggestions: !widget.ocultarTexto,
            autocorrect: !widget.ocultarTexto,
            validator: widget.validator,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              filled: true,
              fillColor: widget.soloLectura
                  ? UniColores.deshabilitado
                  : UniColores.superficie,
              suffixIcon: widget.ocultarTexto
                  ? IconButton(
                      tooltip: _oculto
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(
                        _oculto
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _oculto = !_oculto),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
