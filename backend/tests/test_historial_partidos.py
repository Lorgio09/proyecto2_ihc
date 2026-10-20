from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import Usuario
from app.modules.partidos.schemas import DatosPartido
from app.modules.partidos.service import (
    crear_partido,
    listar_historial,
    salir_partido,
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
        email="organizador@historial.com",
        password_hash="123456",
    )
    jugador = Usuario(
        nombre="Jugador",
        email="jugador@historial.com",
        password_hash="123456",
    )
    otro_jugador = Usuario(
        nombre="Otro jugador",
        email="otro@historial.com",
        password_hash="123456",
    )

    db.add_all([organizador, jugador, otro_jugador])
    db.commit()

    db.refresh(organizador)
    db.refresh(jugador)
    db.refresh(otro_jugador)

    return organizador, jugador, otro_jugador


def crear_partido_prueba(db, organizador, nombre, dias=1):
    return crear_partido(
        DatosPartido(
            nombre=nombre,
            deporte="futbol",
            cantidad_jugadores=10,
            ubicacion="Cancha universitaria",
            tiempo_min="90",
            fecha=datetime.now(timezone.utc) + timedelta(days=dias),
        ),
        organizador,
        db,
    )


def test_historial_vacio_para_usuario_sin_participaciones(db, usuarios):
    _, jugador, _ = usuarios

    resultado = listar_historial(jugador, db)

    assert resultado == []


def test_unirse_genera_registro_para_usuario_correcto(db, usuarios):
    organizador, jugador, otro_jugador = usuarios
    partido = crear_partido_prueba(
        db,
        organizador,
        "Partido del sábado",
    )

    unirse_partido(partido.id, jugador, db)

    historial_jugador = listar_historial(jugador, db)
    historial_otro = listar_historial(otro_jugador, db)

    assert len(historial_jugador) == 1
    assert historial_jugador[0]["accion"] == "se_unio"
    assert historial_jugador[0]["partido_id"] == partido.id
    assert historial_jugador[0]["nombre_partido"] == "Partido del sábado"
    assert historial_otro == []


def test_historial_aparece_del_mas_reciente_al_mas_antiguo(db, usuarios):
    organizador, jugador, _ = usuarios

    primer_partido = crear_partido_prueba(
        db,
        organizador,
        "Primer partido",
        dias=1,
    )
    segundo_partido = crear_partido_prueba(
        db,
        organizador,
        "Segundo partido",
        dias=2,
    )

    unirse_partido(primer_partido.id, jugador, db)
    unirse_partido(segundo_partido.id, jugador, db)

    resultado = listar_historial(jugador, db)

    assert len(resultado) == 2
    assert resultado[0]["partido_id"] == segundo_partido.id
    assert resultado[1]["partido_id"] == primer_partido.id


def test_historial_permanece_despues_de_salir_del_partido(db, usuarios):
    organizador, jugador, _ = usuarios
    partido = crear_partido_prueba(
        db,
        organizador,
        "Partido persistente",
    )

    unirse_partido(partido.id, jugador, db)
    salir_partido(partido.id, jugador, db)

    db.expire_all()
    resultado = listar_historial(jugador, db)

    assert len(resultado) == 1
    assert resultado[0]["partido_id"] == partido.id