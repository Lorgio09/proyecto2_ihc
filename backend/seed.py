"""Idempotent seed data for local development and E2E tests.

Usage (from backend/, with the virtualenv active):

    python seed.py

Test accounts (password for all: Seed1234):
    organizador@unisport.test
    jugador@unisport.test
"""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.database.connection import SessionLocal
from app.database.models import Partido, PartidoParticipante, Usuario
from app.modules.auth.service import hash_password

PASSWORD = "Seed1234"

USUARIOS = [
    ("Organizador Demo", "organizador@unisport.test", "70000001"),
    ("Jugador Demo", "jugador@unisport.test", "70000002"),
]

# (nombre, deporte, cantidad_jugadores, ubicacion, tiempo_min, dias_desde_hoy)
PARTIDOS = [
    ("Fulbito del viernes", "futbol", 10, "Cancha Central", "60", 2),
    ("Basket 3x3", "basquet", 6, "Coliseo Universitario", "45", 3),
    ("Voley de tarde", "voley", 12, "Parque Urbano", "90", 4),
    ("Futsal nocturno", "futbol", 8, "Polideportivo Norte", "60", 5),
]


def main() -> None:
    with SessionLocal() as db:
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
