class HistorialPartido {
  final int id;
  final String accion;
  final DateTime fechaEvento;
  final int partidoId;
  final String nombrePartido;
  final String deporte;
  final String ubicacion;
  final DateTime? fechaPartido;
  final String estado;

  const HistorialPartido({
    required this.id,
    required this.accion,
    required this.fechaEvento,
    required this.partidoId,
    required this.nombrePartido,
    required this.deporte,
    required this.ubicacion,
    required this.fechaPartido,
    required this.estado,
  });

  factory HistorialPartido.fromJson(Map<String, dynamic> json) {
    final fechaPartidoJson = json['fecha_partido'] as String?;

    return HistorialPartido(
      id: json['id'] as int,
      accion: json['accion'] as String,
      fechaEvento: DateTime.parse(json['fecha_evento'] as String),
      partidoId: json['partido_id'] as int,
      nombrePartido: json['nombre_partido'] as String,
      deporte: json['deporte'] as String,
      ubicacion: json['ubicacion'] as String,
      fechaPartido: fechaPartidoJson == null
          ? null
          : DateTime.parse(fechaPartidoJson),
      estado: json['estado'] as String,
    );
  }

  String get accionTexto {
    if (accion == 'se_unio') return 'Te uniste al partido';
    return accion;
  }

  String get deporteTexto {
    if (deporte == 'futbol') return 'Fútbol';
    if (deporte == 'basquet') return 'Básquet';
    if (deporte == 'voley') return 'Vóley';
    return deporte;
  }

  String get estadoTexto {
    if (estado == 'cupos abiertos') return 'Cupos abiertos';
    if (estado == 'equipo completo') return 'Equipo completo';
    return estado;
  }
}
