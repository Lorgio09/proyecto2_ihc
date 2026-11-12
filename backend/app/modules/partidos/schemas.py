from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class RespuestaUsuarioPartido(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    email: str


class DatosPartido(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    cantidad_jugadores: int = Field(ge=1, le=100)
    ubicacion: str = Field(min_length=1, max_length=255)
    tiempo_min: str | None = Field(default=None, min_length=1, max_length=20)
    fecha: datetime | None = None

    deporte: str = Field(
        default="futbol",
        min_length=1,
        max_length=50,
    )


class ActualizacionPartido(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=100)
    cantidad_jugadores: int | None = Field(default=None, ge=1, le=100)
    ubicacion: str | None = Field(default=None, min_length=1, max_length=255)
    tiempo_min: str | None = Field(default=None, min_length=1, max_length=20)
    fecha: datetime | None = None

    deporte: str | None = Field(
        default=None,
        min_length=1,
        max_length=50,
    )


class Reprogramacion(BaseModel):
    fecha: datetime | None = None
    ubicacion: str | None = Field(default=None, min_length=1, max_length=255)
    motivo: str = Field(min_length=1, max_length=255)


class RespuestaPartido(DatosPartido):
    model_config = ConfigDict(from_attributes=True)

    id: int
    estado: str
    participantes: list[RespuestaUsuarioPartido] = []
    cantidad_participantes: int = 0
    suplentes: list[RespuestaUsuarioPartido] = []
    cantidad_suplentes: int = 0
    cupos_disponibles: int = 0
    motivo_reprogramacion: str | None = None
    pendientes_confirmar: list[RespuestaUsuarioPartido] = []
    bajas_tardias: list[RespuestaUsuarioPartido] = []


class RespuestaPartidoExplorar(RespuestaPartido):
    organizador: RespuestaUsuarioPartido


class RespuestaHistorial(BaseModel):
    id: int
    accion: str
    fecha_evento: datetime
    partido_id: int
    nombre_partido: str
    deporte: str
    ubicacion: str
    fecha_partido: datetime | None
    estado: str



class PropuestaEquipos(BaseModel):
    equipo_b: list[int] = Field(min_length=1)
    capitan_rival_id: int


class Marcador(BaseModel):
    goles_a: int = Field(ge=0, le=999)
    goles_b: int = Field(ge=0, le=999)


class Disputa(BaseModel):
    motivo: str = Field(min_length=1, max_length=255)


class RespuestaMarcador(BaseModel):
    goles_a: int
    goles_b: int


class RespuestaVersionResultado(RespuestaMarcador):
    version: int
    estado: str
    motivo_disputa: str | None
    registrado_en: datetime
    respondido_en: datetime | None


class RespuestaValidacion(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    partido_id: int
    nombre: str
    fecha: datetime | None
    ubicacion: str
    organizador: RespuestaUsuarioPartido
    titulares: list[RespuestaUsuarioPartido]
    equipo_a: list[RespuestaUsuarioPartido]
    equipo_b: list[RespuestaUsuarioPartido]
    capitan_rival: RespuestaUsuarioPartido | None
    equipos_aceptados: bool
    partido_jugado: bool
    estado_validacion: str
    es_organizador: bool
    es_capitan: bool
    resultado_definitivo: RespuestaMarcador | None
    resultados: list[RespuestaVersionResultado]
