class Partido {
  final int id;
  final String nombre;
  final int cantidadJugadores;
  final String ubicacion;
  final String? tiempoMin;
  final DateTime? fecha;
  final String estado;

  const Partido({
    required this.id,
    required this.nombre,
    required this.cantidadJugadores,
    required this.ubicacion,
    this.tiempoMin,
    this.fecha,
    required this.estado,
  });

  factory Partido.fromJson(Map<String, dynamic> json) {
    return Partido(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      cantidadJugadores: json['cantidad_jugadores'] as int,
      ubicacion: json['ubicacion'] as String,
      tiempoMin: json['tiempo_min'] as String?,
      fecha: _parseFecha(json['fecha']),
      estado: json['estado'] as String,
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

  const PartidoCreateRequest({
    required this.nombre,
    required this.cantidadJugadores,
    required this.ubicacion,
    this.tiempoMin,
    this.fecha,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'cantidad_jugadores': cantidadJugadores,
    'ubicacion': ubicacion,
    'tiempo_min': tiempoMin,
    'fecha': fecha?.toIso8601String(),
  };
}

class PartidoUpdateRequest {
  final String? nombre;
  final int? cantidadJugadores;
  final String? ubicacion;
  final String? tiempoMin;
  final DateTime? fecha;

  const PartidoUpdateRequest({
    this.nombre,
    this.cantidadJugadores,
    this.ubicacion,
    this.tiempoMin,
    this.fecha,
  });

  Map<String, dynamic> toJson() => {
    if (nombre != null) 'nombre': nombre,
    if (cantidadJugadores != null) 'cantidad_jugadores': cantidadJugadores,
    if (ubicacion != null) 'ubicacion': ubicacion,
    if (tiempoMin != null) 'tiempo_min': tiempoMin,
    if (fecha != null) 'fecha': fecha!.toIso8601String(),
  };
}
