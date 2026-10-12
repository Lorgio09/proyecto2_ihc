"""juan. Aqui estan los servicios para hacer un crud, crea, actualiza, edita y elimina los partidoss"""

from re import match

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.models import Partido, Usuario
from app.modules.partidos.schemas import MatchData, MatchUpdate


def find_match(match_id: int, user: Usuario, db: Session) -> Partido | None:
    return db.scalar(
        select(Partido).where(
            Partido.id == match_id,
            Partido.usuario_id == user.id,
        )
    )


def create_match(data: MatchData, user: Usuario, db: Session) -> Partido:
    match = Partido(
        usuario_id=user.id,
        nombre=data.nombre.strip(),
        cantidad_jugadores=data.cantidad_jugadores,
        ubicacion=data.ubicacion.strip(),
        tiempo_min=data.tiempo_min.strip() if data.tiempo_min else None,
        fecha=data.fecha,
    )
    db.add(match)
    db.commit()
    db.refresh(match)
    return match


def list_matches(user: Usuario, db: Session) -> list[Partido]:
    return list(
        db.scalars(
            select(Partido)
            .where(Partido.usuario_id == user.id)
            .order_by(Partido.fecha, Partido.id)
        ).all()
    )


def update_match(match: Partido, data: MatchUpdate, db: Session) -> Partido:
    changes = data.model_dump(exclude_unset=True)
    for name in ("nombre", "ubicacion", "tiempo_min"):
        if name in changes and changes[name] is not None:
            changes[name] = changes[name].strip()
    for name, value in changes.items():
        setattr(match, name, value)

    db.commit()
    db.refresh(match)
    return match


def delete_match(match: Partido, db: Session) -> None:
    db.delete(match)
    db.commit()



def complete_team(match: Partido, db: Session) -> Partido:
    if match.estado != "Cupos abiertos":
        raise ValueError("El equipo ya esta completo")
    match.estado = "equipo completo"
    db.commit()
    db.refresh(match)

    return match