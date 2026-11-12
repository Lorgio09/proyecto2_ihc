class UsuarioPartido {
  final int id;
  final String nombre;
  final String email;

  const UsuarioPartido({
    required this.id,
    required this.nombre,
    required this.email,
  });

  factory UsuarioPartido.fromJson(Map<String, dynamic> json) {
    return UsuarioPartido(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
    );
  }
}

class Partido {
  final int id;
  final String nombre;
  final int cantidadJugadores;
  final String ubicacion;
  final String? tiempoMin;
  final DateTime? fecha;
  final String estado;
  final UsuarioPartido? organizador;
  final List<UsuarioPartido> participantes;
  final int cantidadParticipantes;
  final int cuposDisponibles;
  // Wait for a holder to leave, in order of arrival.
  final List<UsuarioPartido> suplentes;
  final int cantidadSuplentes;
  // After a reschedule: why it changed and which holders still have to answer.
  final String? motivoReprogramacion;
  final List<UsuarioPartido> pendientesConfirmar;
  // Players who left less than 2 hours before kick-off (visible to the organizer).
  final List<UsuarioPartido> bajasTardias;

  final String deporte; // Nuevo atributo para el deporte


  const Partido({
    required this.id,
    required this.nombre,
    required this.cantidadJugadores,
    required this.ubicacion,
    this.tiempoMin,
    this.fecha,
    required this.estado,
    this.organizador,
    this.participantes = const [],
    this.cantidadParticipantes = 0,
    this.cuposDisponibles = 0,
    this.suplentes = const [],
    this.cantidadSuplentes = 0,
    this.motivoReprogramacion,
    this.pendientesConfirmar = const [],
    this.bajasTardias = const [],
    required this.deporte,
  });

  bool get tieneRespuestasPendientes => pendientesConfirmar.isNotEmpty;

  /// Leaving from now on counts as a late withdrawal (same 2 h rule as the API).
  bool get salidaSeriaTardia =>
      fecha != null &&
      fecha!.difference(DateTime.now()) < const Duration(hours: 2);

  bool debeReconfirmar(int usuarioId) =>
      pendientesConfirmar.any((usuario) => usuario.id == usuarioId);

  String get deporteTexto {
    if (deporte == 'futbol') return 'Fútbol';
    if (deporte == 'basquet') return 'Básquet';
    if (deporte == 'voley') return 'Vóley';
    return deporte;
  }

  String get estadoTexto {
    if (estado.trim().toLowerCase() == 'cupos abiertos') {
      return 'Cupos abiertos';
    }
    if (estado.trim().toLowerCase() == 'equipo completo') {
      return 'Equipo completo';
    }
    return estado;
  }

  factory Partido.fromJson(Map<String, dynamic> json) {
    final participantesJson = json['participantes'] as List? ?? [];
    final suplentesJson = json['suplentes'] as List? ?? [];
    final pendientesJson = json['pendientes_confirmar'] as List? ?? [];
    final bajasJson = json['bajas_tardias'] as List? ?? [];
    final organizadorJson = json['organizador'];

    return Partido(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      cantidadJugadores: json['cantidad_jugadores'] as int,
      ubicacion: json['ubicacion'] as String,
      tiempoMin: json['tiempo_min'] as String?,
      fecha: _parseFecha(json['fecha']),
      estado: json['estado'] as String,
      organizador: organizadorJson is Map<String, dynamic>
          ? UsuarioPartido.fromJson(organizadorJson)
          : null,
      participantes: participantesJson
          .whereType<Map<String, dynamic>>()
          .map(UsuarioPartido.fromJson)
          .toList(),
      cantidadParticipantes: json['cantidad_participantes'] as int? ?? 0,
      cuposDisponibles: json['cupos_disponibles'] as int? ?? 0,
      suplentes: suplentesJson
          .whereType<Map<String, dynamic>>()
          .map(UsuarioPartido.fromJson)
          .toList(),
      cantidadSuplentes: json['cantidad_suplentes'] as int? ?? 0,
      motivoReprogramacion: json['motivo_reprogramacion'] as String?,
      pendientesConfirmar: pendientesJson
          .whereType<Map<String, dynamic>>()
          .map(UsuarioPartido.fromJson)
          .toList(),
      bajasTardias: bajasJson
          .whereType<Map<String, dynamic>>()
          .map(UsuarioPartido.fromJson)
          .toList(),

      deporte: json['deporte'] as String? ?? 'futbol',
    );
  }

  static DateTime? _parseFecha(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('La fecha del partido debe ser un texto');
    }
    // The API stores UTC; show and edit the date in the user's local time.
    return DateTime.parse(value).toLocal();
  }
}

class PartidoCreateRequest {
  final String nombre;
  final int cantidadJugadores;
  final String ubicacion;
  final String? tiempoMin;
  final DateTime? fecha;

  final String deporte; // Nuevo atributo para el deporte

  const PartidoCreateRequest({
    required this.nombre,
    required this.cantidadJugadores,
    required this.ubicacion,
    this.tiempoMin,
    this.fecha,

    required this.deporte,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'cantidad_jugadores': cantidadJugadores,
    'ubicacion': ubicacion,
    'tiempo_min': tiempoMin,
    'fecha': fecha?.toUtc().toIso8601String(),

    'deporte': deporte,
  };
}

class PartidoUpdateRequest {
  final String? nombre;
  final int? cantidadJugadores;
  final String? ubicacion;
  final String? tiempoMin;
  final DateTime? fecha;

  final String? deporte; // Nuevo atributo para el deporte

  const PartidoUpdateRequest({
    this.nombre,
    this.cantidadJugadores,
    this.ubicacion,
    this.tiempoMin,
    this.fecha,

    this.deporte,
  });

  Map<String, dynamic> toJson() => {
    if (nombre != null) 'nombre': nombre,
    if (cantidadJugadores != null) 'cantidad_jugadores': cantidadJugadores,
    if (ubicacion != null) 'ubicacion': ubicacion,
    if (tiempoMin != null) 'tiempo_min': tiempoMin,
    if (fecha != null) 'fecha': fecha!.toUtc().toIso8601String(),

    if (deporte != null) 'deporte': deporte,
  };
}
