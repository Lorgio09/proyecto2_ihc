"""Datos semilla (seed) idempotentes para el desarrollo local y las pruebas E2E.

Uso (desde backend/, con el entorno virtual activado):

    python seed.py           # agrega lo que falte
    python seed.py --reset   # primero borra los partidos de los usuarios semilla
                             # (y, en cascada, sus participantes e historial)

La validación del resultado (Tarea 8) usa dos partidos más con jugadores ya inscritos:
    "Clásico de la facultad"  jugado hace 3 horas; equipos aceptados, el capitán
                              rival es jugador2.
    "Amistoso del sábado"     la próxima semana; todavía sin equipos propuestos.

La baja tardía (Tarea 9) usa otros dos:
    "Baja con tiempo"          en 2 días, 1 lugar: jugador lo ocupa y
                               jugador2 espera como suplente.
    "Baja de último momento"   empieza en 90 minutos; jugador3 está inscrito, así que
                               salirse ahora cuenta como baja tardía.

Cuentas de prueba (contraseña de todas: Seed1234):
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
    # Solo dos lugares, así que el tercer jugador en unirse queda como suplente.
    ("Duelo de dos", "futbol", 2, "Cancha Chica", "30", 6),
]


def reset(db) -> None:
    """Borra los partidos de los usuarios semilla, por ejemplo los que dejaron las pruebas E2E."""
    emails = [email for _, email, _ in USUARIOS]
    ids = db.scalars(select(Usuario.id).where(Usuario.email.in_(emails))).all()
    for partido in db.scalars(select(Partido).where(Partido.usuario_id.in_(ids))):
        db.delete(partido)
    # Un token de recuperación pendiente vuelve ambigua la siguiente recuperación: el
    # endpoint de restablecimiento busca al usuario solo por el token, que siempre es 123456.
    for usuario in db.scalars(select(Usuario).where(Usuario.id.in_(ids))):
        usuario.token_recuperacion = None
        usuario.token_expiracion = None
    # Cuentas creadas por las pruebas E2E (registro, recuperación de contraseña).
    for usuario in db.scalars(
        select(Usuario).where(Usuario.email.like("e2e-%@unisport.test"))
    ):
        db.delete(usuario)
    db.commit()


# (nombre, horas_desde_ahora, equipo de cada jugador, capitán rival, aceptados)
PARTIDOS_VALIDACION = [
    (
        "Clásico de la facultad",
        -3,
        {
            "jugador@unisport.test": "A",
            "jugador2@unisport.test": "B",
            "jugador3@unisport.test": "B",
        },
        "jugador2@unisport.test",
        True,
    ),
    (
        "Amistoso del sábado",
        24 * 7,
        {
            "jugador@unisport.test": None,
            "jugador2@unisport.test": None,
            "jugador3@unisport.test": None,
        },
        None,
        False,
    ),
]


def crear_partidos_de_validacion(db, usuarios, organizador, ahora) -> None:
    """Partidos para el flujo de validación del resultado, creados con sus jugadores.

    El partido ya jugado no se puede armar con la API (un partido necesita una fecha
    futura para crearse o para unirse), así que el seed lo escribe directamente.
    """
    for nombre, horas, equipos, capitan, aceptados in PARTIDOS_VALIDACION:
        existe = db.scalar(
            select(Partido).where(
                Partido.usuario_id == organizador.id,
                Partido.nombre == nombre,
            )
        )
        if existe is not None:
            continue
        partido = Partido(
            usuario_id=organizador.id,
            nombre=nombre,
            deporte="futbol",
            cantidad_jugadores=6,
            ubicacion="Cancha FICCT",
            tiempo_min="60",
            fecha=ahora + timedelta(hours=horas),
            estado="cupos abiertos",
            capitan_rival_id=usuarios[capitan].id if capitan else None,
            equipos_aceptados=aceptados,
        )
        db.add(partido)
        db.flush()
        for orden, (email, equipo) in enumerate(equipos.items()):
            db.add(
                PartidoParticipante(
                    partido_id=partido.id,
                    usuario_id=usuarios[email].id,
                    equipo=equipo,
                    unido_en=ahora - timedelta(days=2, minutes=-orden),
                )
            )
    db.commit()


# (nombre, minutos_desde_ahora, cupos, [(email, es_suplente)])
PARTIDOS_BAJA = [
    (
        "Baja con tiempo",
        60 * 48,
        1,
        [("jugador@unisport.test", False), ("jugador2@unisport.test", True)],
    ),
    (
        "Baja de último momento",
        90,
        4,
        [("jugador3@unisport.test", False)],
    ),
]


def crear_partidos_de_baja(db, usuarios, organizador, ahora) -> None:
    """Partidos para el flujo de baja tardía, creados con sus jugadores."""
    for nombre, minutos, cupos, jugadores in PARTIDOS_BAJA:
        existe = db.scalar(
            select(Partido).where(
                Partido.usuario_id == organizador.id,
                Partido.nombre == nombre,
            )
        )
        if existe is not None:
            continue
        titulares = sum(1 for _, es_suplente in jugadores if not es_suplente)
        partido = Partido(
            usuario_id=organizador.id,
            nombre=nombre,
            deporte="futbol",
            cantidad_jugadores=cupos,
            ubicacion="Cancha FICCT",
            tiempo_min="60",
            fecha=ahora + timedelta(minutes=minutos),
            estado="equipo completo" if titulares >= cupos else "cupos abiertos",
        )
        db.add(partido)
        db.flush()
        for orden, (email, es_suplente) in enumerate(jugadores):
            db.add(
                PartidoParticipante(
                    partido_id=partido.id,
                    usuario_id=usuarios[email].id,
                    es_suplente=es_suplente,
                    unido_en=ahora - timedelta(days=1, minutes=-orden),
                )
            )
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

        crear_partidos_de_validacion(db, usuarios, organizador, ahora)
        crear_partidos_de_baja(db, usuarios, organizador, ahora)

        print(f"Usuarios: {db.query(Usuario).count()}")
        print(f"Partidos: {db.query(Partido).count()}")
        print(f"Participantes: {db.query(PartidoParticipante).count()}")


if __name__ == "__main__":
    main()
