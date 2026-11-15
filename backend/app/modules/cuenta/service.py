"""The account's own data: what UniSport keeps about a person, to see it and
take it away. Only that person's data: never other players' names or emails,
and never the password hash or recovery tokens."""
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.models import HistorialParticipacion, Partido, PartidoParticipante, Usuario


def _fecha(valor: datetime | None) -> str | None:
    return valor.isoformat() if valor is not None else None


def mis_datos(usuario: Usuario, base_datos: Session) -> dict:
    organizados = base_datos.scalars(
        select(Partido)
        .where(Partido.usuario_id == usuario.id)
        .order_by(Partido.fecha, Partido.id)
    ).all()
    participaciones = base_datos.scalars(
        select(PartidoParticipante)
        .where(PartidoParticipante.usuario_id == usuario.id)
        .order_by(PartidoParticipante.unido_en)
    ).all()
    historial = base_datos.scalars(
        select(HistorialParticipacion)
        .where(HistorialParticipacion.usuario_id == usuario.id)
        .order_by(HistorialParticipacion.fecha_evento, HistorialParticipacion.id)
    ).all()
    nombres = {
        partido.id: partido.nombre
        for partido in base_datos.scalars(
            select(Partido).where(
                Partido.id.in_({item.partido_id for item in historial})
            )
        )
    }

    return {
        "generado_en": datetime.now(timezone.utc).isoformat(),
        "cuenta": {
            "nombre": usuario.nombre,
            "email": usuario.email,
            "telefono": usuario.telefono,
        },
        "partidos_organizados": [
            {
                "nombre": partido.nombre,
                "deporte": partido.deporte,
                "fecha": _fecha(partido.fecha),
                "ubicacion": partido.ubicacion,
                "cantidad_jugadores": partido.cantidad_jugadores,
                "estado": partido.estado,
            }
            for partido in organizados
        ],
        "participaciones": [
            {
                "partido": item.partido.nombre,
                "fecha": _fecha(item.partido.fecha),
                "ubicacion": item.partido.ubicacion,
                "rol": "suplente" if item.es_suplente else "titular",
                "equipo": item.equipo,
                "unido_en": _fecha(item.unido_en),
            }
            for item in participaciones
        ],
        "historial": [
            {
                "accion": item.accion,
                "fecha": _fecha(item.fecha_evento),
                "partido": nombres.get(item.partido_id),
            }
            for item in historial
        ],
    }
