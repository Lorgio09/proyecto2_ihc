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


class RespuestaPartido(DatosPartido):
    model_config = ConfigDict(from_attributes=True)

    id: int
    estado: str
    participantes: list[RespuestaUsuarioPartido] = []
    cantidad_participantes: int = 0
    cupos_disponibles: int = 0


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

