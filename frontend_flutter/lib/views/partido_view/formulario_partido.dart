import 'package:flutter/material.dart';

import '../../models/partido.dart';
import '../../widgets/ayuda.dart';
import '../../widgets/boton_guardar.dart';
import '../../widgets/input.dart';

class FormularioPartido extends StatefulWidget {
  const FormularioPartido({super.key, this.partido});

  final Partido? partido;

  @override
  State<FormularioPartido> createState() => _FormularioPartidoState();
}

class _FormularioPartidoState extends State<FormularioPartido> {
  late final TextEditingController nombreController;
  late final TextEditingController ubicacionController;
  late final TextEditingController cantidadJugadoresController;
  late final TextEditingController tiempoController;
  late final TextEditingController estadoController;
  final formularioKey = GlobalKey<FormState>();
  DateTime? fecha;
  String? errorFecha;
  String deporte = 'futbol';  // Nuevo atributo para el deporte

  @override
  void initState() {
    super.initState();
    nombreController = TextEditingController(text: widget.partido?.nombre);
    ubicacionController = TextEditingController(
      text: widget.partido?.ubicacion,
    );
    cantidadJugadoresController = TextEditingController(
      text: widget.partido?.cantidadJugadores.toString(),
    );
    tiempoController = TextEditingController(text: widget.partido?.tiempoMin);
    estadoController = TextEditingController(text: widget.partido?.estadoTexto);
    fecha = widget.partido?.fecha;
    deporte = widget.partido?.deporte ?? 'futbol';
  }

  @override
  void dispose() {
    nombreController.dispose();
    ubicacionController.dispose();
    cantidadJugadoresController.dispose();
    tiempoController.dispose();
    super.dispose();
  }

  Future<void> seleccionarFecha() async {
    final manana = DateTime.now();
    final primeraFecha = DateTime(
      manana.year,
      manana.month,
      manana.day + 1,
    );
    final fechaSeleccionada = await showDatePicker(
      context: context,
      firstDate: primeraFecha,
      lastDate: DateTime(2035),
      initialDate: fecha != null && !fecha!.isBefore(primeraFecha)
          ? fecha!
          : primeraFecha,
    );

    if (fechaSeleccionada != null) {
      setState(() {
        fecha = fechaSeleccionada;
        errorFecha = null;
      });
    }
  }

  void restarjugadores() {
    final cantidad = int.tryParse(cantidadJugadoresController.text.trim());
    if (cantidad != null && cantidad > 1) {
      cantidadJugadoresController.text = (cantidad - 1).toString();
    }
  }

  void sumarjugadores() {
    final cantidad = int.tryParse(cantidadJugadoresController.text.trim());
    if (cantidad != null && cantidad < 50) {
      cantidadJugadoresController.text = (cantidad + 1).toString();
    }
  }

  String? validarTexto(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? validarCantidad(String? valor) {
    final cantidad = int.tryParse(valor?.trim() ?? '');
    if (cantidad == null || cantidad < 1 || cantidad > 100) {
      return 'Usa un número entre 1 y 100';
    }
    return null;
  }

  void guardar() {
    final hoy = DateTime.now();
    final primeraFecha = DateTime(hoy.year, hoy.month, hoy.day + 1);
    if (fecha == null) {
      setState(() => errorFecha = 'La fecha es obligatoria');
      return;
    }
    if (fecha!.isBefore(primeraFecha)) {
      setState(() => errorFecha = 'La fecha debe ser futura');
      return;
    }
    if (!formularioKey.currentState!.validate()) return;

    Navigator.pop(context, {
      'nombre': nombreController.text.trim(),
      'cantidadJugadores': int.parse(cantidadJugadoresController.text.trim()),
      'ubicacion': ubicacionController.text.trim(),
      'tiempoMin': tiempoController.text.trim().isEmpty
          ? null
          : tiempoController.text.trim(),
      'fecha': fecha,
      'deporte': deporte,
    });
  }
 
  @override
  Widget build(BuildContext context) {
    final editando = widget.partido != null;
    final equipoCompleto =
        widget.partido?.estado.trim().toLowerCase() == 'equipo completo';

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(editando ? 'Editar partido' : 'Nuevo partido'),
          ),
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              mostrarAyuda(
                context,
                'Ayuda del formulario',
                'Ingresa el nombre, deporte y ubicación del partido.\n\n'
                'La cantidad de jugadores indica el máximo de participantes.\n\n'
                'Selecciona la fecha y pulsa Guardar para registrar '
                'los cambios.',
              );
            },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formularioKey,
          child: Column(
            children: [
              Input(
                controlador: nombreController,
                etiqueta: 'Nombre',
                validator: validarTexto,
              ),
              DropdownButtonFormField<String>(
                initialValue: deporte,
                decoration: const InputDecoration(labelText: 'Deporte'),
                items: const [
                  DropdownMenuItem(value: 'futbol', child: Text('Fútbol')),
                  DropdownMenuItem(value: 'basquet', child: Text('Básquet')),
                  DropdownMenuItem(value: 'voley', child: Text('Vóley')),
                ],
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() => deporte = valor);
                  }
                },
              ),
              Input(
                controlador: ubicacionController,
                etiqueta: 'Ubicación',
                validator: validarTexto,
              ),
              Row(children: [
                TextButton(
                  onPressed: equipoCompleto ? null : restarjugadores,
                  child: const Text('-'),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Input(
                        controlador: cantidadJugadoresController,
                        etiqueta: 'Cantidad de jugadores',
                        soloLectura: equipoCompleto,
                        validator: validarCantidad,
                      ),
                      if (equipoCompleto) ...[
                        Text(
                          'No se puede modificar porque el equipo ya está completo',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: equipoCompleto ? null : sumarjugadores,
                  child: const Text('+'),
                ),
              ],),
          
              Input(
                controlador: tiempoController,
                etiqueta: 'Tiempo en minutos',
          
              ),
              Input(
                controlador: estadoController,
                etiqueta: 'Estado',
                soloLectura: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fecha == null
                          ? 'Sin fecha'
                          : '${fecha!.day}/${fecha!.month}/${fecha!.year}',
                    ),
                  ),
                  TextButton(
                    onPressed: seleccionarFecha,
                    child: const Text('Elegir fecha'),
                  ),
                ],
              ),
              if (errorFecha != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    errorFecha!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonGuardar(texto: 'Guardar', alPresionar: guardar),
      ],
    );
  }
}
