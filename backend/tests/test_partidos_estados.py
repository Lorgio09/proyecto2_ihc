import pytest

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import Usuario

from app.modules.partidos.schemas import MatchData
from app.modules.partidos.service import (
    complete_team,
    create_match,
)

engine = create_engine(
    "sqlite://",
    connect_args={
        "check_same_thread": False,
    },
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(
    bind=engine,
)

@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)

    session = TestingSessionLocal()

    yield session

    session.close()

    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def user(db):
    usuario = Usuario(
        nombre="Juan",
        email="juan@test.com",
        password_hash="123456",
        telefono="123456789",
    )

    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    return usuario

@pytest.fixture
def partido(db, user):
    data = MatchData(
        nombre="Partido de prueba",
        cantidad_jugadores=10,
        ubicacion="Cancha universitaria",
        tiempo_min="90",
        fecha=None,
    )

    return create_match(
        data,
        user,
        db,
    )

# PRUEBA 1
# Estado inicial correcto

def test_estado_inicial_es_cupos_abiertos(partido):

    assert partido.estado == "Cupos abiertos"


# PRUEBA 2
# Completar equipo cambia el estado a "equipo completo"

def test_completar_equipo_cambia_estado(db, partido):

    partido_actualizado = complete_team(
        partido,
        db,
    )

    assert partido_actualizado.estado == "equipo completo"


# PRUEBA 3
# Una transicion inavalida debe rechazarse

def test_no_permite_completar_dos_veces(db, partido):

    complete_team(
        partido,
        db,
    )

    with pytest.raises(ValueError):
        complete_team(
            partido,
            db,
        )


# PRUEBA 4
# Los demas datos deben conservarse

def test_completar_equipo_conserva_datos(db, partido):

    nombre_original = partido.nombre
    jugadores_original = partido.cantidad_jugadores
    ubicacion_original = partido.ubicacion
    tiempo_original = partido.tiempo_min
    usuario_original = partido.usuario_id

    partido_actualizado = complete_team(
        partido,
        db,
    )

    assert partido_actualizado.nombre == nombre_original

    assert (
        partido_actualizado.cantidad_jugadores 
        == jugadores_original
    )

    assert partido_actualizado.ubicacion == ubicacion_original

    assert partido_actualizado.tiempo_min == tiempo_original

    assert partido_actualizado.usuario_id == usuario_original

    assert partido_actualizado.estado == "equipo completo"

