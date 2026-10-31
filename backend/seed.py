"""Idempotent seed data for local development and E2E tests.

Usage (from backend/, with the virtualenv active):

    python seed.py           # add whatever is missing
    python seed.py --reset   # first delete the seed users' matches (and, by
                             # cascade, their participants and history)

Test accounts (password for all: Seed1234):
    organizador@unisport.test
    jugador@unisport.test
    jugador2@unisport.test
    jugador3@unisport.test
"""

import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.database.connection import SessionLocal
from app.database.models import Partido, PartidoParticipante, Usuario
from app.modules.auth.service import hash_password

PASSWORD = "Seed1234"

USUARIOS = [
    ("Organizador Demo", "organizador@unisport.test", "70000001"),
    ("Jugador Demo", "jugador@unisport.test", "70000002"),
    ("Segundo Jugador", "jugador2@unisport.test", "70000003"),
    ("Tercer Jugador", "jugador3@unisport.test", "70000004"),
]

# (nombre, deporte, cantidad_jugadores, ubicacion, tiempo_min, dias_desde_hoy)
PARTIDOS = [
    ("Fulbito del viernes", "futbol", 10, "Cancha Central", "60", 2),
    ("Basket 3x3", "basquet", 6, "Coliseo Universitario", "45", 3),
    ("Voley de tarde", "voley", 12, "Parque Urbano", "90", 4),
    ("Futsal nocturno", "futbol", 8, "Polideportivo Norte", "60", 5),
    # Two spots only, so the third player to join becomes a substitute.
    ("Duelo de dos", "futbol", 2, "Cancha Chica", "30", 6),
]


def reset(db) -> None:
    """Remove the matches the seed users own, e.g. those left by E2E runs."""
    emails = [email for _, email, _ in USUARIOS]
    ids = db.scalars(select(Usuario.id).where(Usuario.email.in_(emails))).all()
    for partido in db.scalars(select(Partido).where(Partido.usuario_id.in_(ids))):
        db.delete(partido)
    # A pending recovery token makes the next recovery ambiguous: the reset
    # endpoint finds its user by token alone, and the token is always 123456.
    for usuario in db.scalars(select(Usuario).where(Usuario.id.in_(ids))):
        usuario.token_recuperacion = None
        usuario.token_expiracion = None
    # Accounts created by the E2E tests (registration, password recovery).
    for usuario in db.scalars(
        select(Usuario).where(Usuario.email.like("e2e-%@unisport.test"))
    ):
        db.delete(usuario)
    db.commit()


def main() -> None:
    with SessionLocal() as db:
        if "--reset" in sys.argv[1:]:
            reset(db)
        usuarios = {}
        for nombre, email, telefono in USUARIOS:
            usuario = db.scalar(select(Usuario).where(Usuario.email == email))
            if usuario is None:
                usuario = Usuario(
                    nombre=nombre,
                    email=email,
                    telefono=telefono,
                    password_hash=hash_password(PASSWORD),
                )
                db.add(usuario)
                db.flush()
            usuarios[email] = usuario

        organizador = usuarios["organizador@unisport.test"]
        ahora = datetime.now(timezone.utc)

        for nombre, deporte, cantidad, ubicacion, tiempo, dias in PARTIDOS:
            existe = db.scalar(
                select(Partido).where(
                    Partido.usuario_id == organizador.id,
                    Partido.nombre == nombre,
                )
            )
            if existe is not None:
                continue
            db.add(
                Partido(
                    usuario_id=organizador.id,
                    nombre=nombre,
                    deporte=deporte,
                    cantidad_jugadores=cantidad,
                    ubicacion=ubicacion,
                    tiempo_min=tiempo,
                    fecha=ahora + timedelta(days=dias),
                    estado="cupos abiertos",
                )
            )
        db.commit()

        print(f"Usuarios: {db.query(Usuario).count()}")
        print(f"Partidos: {db.query(Partido).count()}")
        print(f"Participantes: {db.query(PartidoParticipante).count()}")


if __name__ == "__main__":
    main()
