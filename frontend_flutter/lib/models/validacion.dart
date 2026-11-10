import 'partido.dart';

/// One score version. A correction adds a new one; none is deleted.
class VersionResultado {
  final int version;
  final int golesA;
  final int golesB;
  final String estado;
  final String? motivoDisputa;
  final DateTime registradoEn;

  const VersionResultado({
    required this.version,
    required this.golesA,
    required this.golesB,
    required this.estado,
    required this.registradoEn,
    this.motivoDisputa,
  });

  factory VersionResultado.fromJson(Map<String, dynamic> json) {
    return VersionResultado(
      version: json['version'] as int,
      golesA: json['goles_a'] as int,
      golesB: json['goles_b'] as int,
      estado: json['estado'] as String,
      motivoDisputa: json['motivo_disputa'] as String?,
      registradoEn: DateTime.parse(json['registrado_en'] as String).toLocal(),
    );
  }

  String get estadoTexto => switch (estado) {
    'pendiente' => 'Esperando validación',
    'disputado' => 'Disputado',
    'confirmado' => 'Confirmado',
    _ => estado,
  };
}

/// Teams, rival captain and score history of a match, seen by one user.
class Validacion {
  final int partidoId;
  final String nombre;
  final DateTime? fecha;
  final String ubicacion;
  final UsuarioPartido organizador;
  final List<UsuarioPartido> titulares;
  final List<UsuarioPartido> equipoA;
  final List<UsuarioPartido> equipoB;
  final UsuarioPartido? capitanRival;
  final bool equiposAceptados;
  final bool partidoJugado;
  final String estado;
  final bool esOrganizador;
  final bool esCapitan;
  final (int, int)? resultadoDefinitivo;
  final List<VersionResultado> resultados;

  const Validacion({
    required this.partidoId,
    required this.nombre,
    required this.ubicacion,
    required this.organizador,
    required this.titulares,
    required this.equipoA,
    required this.equipoB,
    required this.equiposAceptados,
    required this.partidoJugado,
    required this.estado,
    required this.esOrganizador,
    required this.esCapitan,
    required this.resultados,
    this.fecha,
    this.capitanRival,
    this.resultadoDefinitivo,
  });

  factory Validacion.fromJson(Map<String, dynamic> json) {
    List<UsuarioPartido> usuarios(String clave) => (json[clave] as List? ?? [])
        .map((item) => UsuarioPartido.fromJson(item as Map<String, dynamic>))
        .toList();
    final capitan = json['capitan_rival'];
    final definitivo = json['resultado_definitivo'];
    final fecha = json['fecha'];

    return Validacion(
      partidoId: json['partido_id'] as int,
      nombre: json['nombre'] as String,
      fecha: fecha == null ? null : DateTime.parse(fecha as String).toLocal(),
      ubicacion: json['ubicacion'] as String,
      organizador: UsuarioPartido.fromJson(
        json['organizador'] as Map<String, dynamic>,
      ),
      titulares: usuarios('titulares'),
      equipoA: usuarios('equipo_a'),
      equipoB: usuarios('equipo_b'),
      capitanRival: capitan == null
          ? null
          : UsuarioPartido.fromJson(capitan as Map<String, dynamic>),
      equiposAceptados: json['equipos_aceptados'] as bool,
      partidoJugado: json['partido_jugado'] as bool,
      estado: json['estado_validacion'] as String,
      esOrganizador: json['es_organizador'] as bool,
      esCapitan: json['es_capitan'] as bool,
      resultadoDefinitivo: definitivo == null
          ? null
          : (definitivo['goles_a'] as int, definitivo['goles_b'] as int),
      resultados: (json['resultados'] as List? ?? [])
          .map(
            (item) => VersionResultado.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  String get estadoTexto => switch (estado) {
    'sin_equipos' => 'El organizador todavía no propuso los equipos',
    'equipos_propuestos' => 'Esperando que el capitán rival acepte los equipos',
    'equipos_aceptados' =>
      partidoJugado
          ? 'Equipos aceptados. Falta registrar el marcador'
          : 'Equipos aceptados. El marcador se registra al terminar el partido',
    'resultado_pendiente' => 'Marcador esperando la validación del capitán',
    'resultado_disputado' =>
      'Marcador disputado. El organizador debe corregirlo',
    'resultado_confirmado' => 'Resultado confirmado',
    _ => estado,
  };
}
