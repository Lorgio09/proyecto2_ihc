from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import PartidoParticipante, Usuario
from app.modules.partidos.schemas import DatosPartido
from app.modules.partidos.service import (
    ErrorPartido,
    crear_partido,
    datos_partido,
    listar_partidos_publicos,
    unirse_partido,
)


engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(bind=engine)


@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def usuarios(db):
    organizador = Usuario(
        nombre="Organizador",
        email="organizador@test.com",
        password_hash="123456",
    )
    jugador = Usuario(
        nombre="Jugador",
        email="jugador@test.com",
        password_hash="123456",
    )
    otro_jugador = Usuario(
        nombre="Otro jugador",
        email="otro@test.com",
        password_hash="123456",
    )
    db.add_all([organizador, jugador, otro_jugador])
    db.commit()
    db.refresh(organizador)
    db.refresh(jugador)
    db.refresh(otro_jugador)
    return organizador, jugador, otro_jugador


def crear_partido_prueba(db, organizador, cantidad=2, fecha=None):
    return crear_partido(
        DatosPartido(
            nombre="Partido abierto",
            cantidad_jugadores=cantidad,
            ubicacion="Cancha central",
            tiempo_min="90",
            fecha=fecha,
        ),
        organizador,
        db,
    )


def obtener_error(accion):
    with pytest.raises(ErrorPartido) as error:
        accion()
    return error.value


def test_usuario_puede_unirse_a_partido_futuro(db, usuarios):
    organizador, jugador, _ = usuarios
    fecha = datetime.now(timezone.utc) + timedelta(days=1)
    partido = crear_partido_prueba(db, organizador, fecha=fecha)

    partido_actualizado = unirse_partido(partido.id, jugador, db)

    assert partido_actualizado.estado == "cupos abiertos"
    assert partido_actualizado.cantidad_jugadores == 2
    assert db.scalar(
        select(PartidoParticipante).where(
            PartidoParticipante.partido_id == partido.id,
            PartidoParticipante.usuario_id == jugador.id,
        )
    ) is not None


def test_no_se_puede_unir_a_fecha_pasada(db, usuarios):
    organizador, jugador, _ = usuarios
    fecha = datetime.now(timezone.utc) - timedelta(days=1)
    partido = crear_partido_prueba(db, organizador, fecha=fecha)

    error = obtener_error(lambda: unirse_partido(partido.id, jugador, db))

    assert error.codigo == "FECHA_PASADA"


def test_crear_partido_guarda_y_devuelve_el_deporte(db, usuarios):
    organizador, _, _ = usuarios
    partido = crear_partido(
        DatosPartido(
            nombre="Partido de basquet",
            deporte="basquet",
            cantidad_jugadores=10,
            ubicacion="Cancha central",
            tiempo_min="90",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )

    assert partido.deporte == "basquet"
    assert datos_partido(partido)["deporte"] == "basquet"


def test_filtra_partido_por_deporte(db, usuarios):
    organizador, jugador, _ = usuarios
    partido = crear_partido(
        DatosPartido(
            nombre="Futbol en zona sur",
            deporte="futbol",
            cantidad_jugadores=10,
            ubicacion="Zona Sur",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )

    resultado = listar_partidos_publicos(
        jugador,
        db,
        deporte="futbol",
        zona="sur",
        solo_con_cupos=True,
    )

    assert len(resultado) == 1
    assert resultado[0].id == partido.id


def test_filtro_sin_resultados(db, usuarios):
    organizador, jugador, _ = usuarios
    crear_partido(
        DatosPartido(
            nombre="Partido de futbol",
            deporte="futbol",
            cantidad_jugadores=10,
            ubicacion="Zona Sur",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )

    resultado = listar_partidos_publicos(jugador, db, deporte="voley")

    assert resultado == []


