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
    required this.deporte,
  });

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

      deporte: json['deporte'] as String? ?? 'futbol',
    );
  }

  static DateTime? _parseFecha(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('La fecha del partido debe ser un texto');
    }
    return DateTime.parse(value);
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
    'fecha': fecha?.toIso8601String(),

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
    if (fecha != null) 'fecha': fecha!.toIso8601String(),

    if (deporte != null) 'deporte': deporte,
  };
}
