from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import HistorialParticipacion, Usuario
from app.modules.partidos.schemas import DatosPartido
from app.modules.partidos.service import (
    ErrorPartido,
    crear_partido,
    datos_partido,
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
    creados = [
        Usuario(nombre=nombre, email=f"{nombre}@test.com", password_hash="x")
        for nombre in ("organizador", "ana", "beto")
    ]
    db.add_all(creados)
    db.commit()
    for usuario in creados:
        db.refresh(usuario)
    return creados


def partido_en(db, usuarios, falta: timedelta):
    """One holder spot taken by ana, beto waiting as substitute."""
    organizador, ana, beto = usuarios
    partido = crear_partido(
        DatosPartido(
            nombre="Duelo",
            cantidad_jugadores=1,
            ubicacion="Cancha central",
            fecha=datetime.now(timezone.utc) + falta,
        ),
        organizador,
        db,
    )
    unirse_partido(partido.id, ana, db)
    unirse_partido(partido.id, beto, db)
    return partido


def nombres(lista):
    return [usuario.nombre for usuario in lista]


def acciones(db, usuario):
    return db.scalars(
        select(HistorialParticipacion.accion).where(
            HistorialParticipacion.usuario_id == usuario.id
        )
    ).all()


def test_baja_a_tiempo_sube_al_suplente_sin_registrarse_como_tardia(db, usuarios):
    _, ana, beto = usuarios
    partido = partido_en(db, usuarios, timedelta(days=1))

    salir_partido(partido.id, ana, db)

    datos = datos_partido(partido)
    assert nombres(datos["participantes"]) == ["beto"]
    assert datos["suplentes"] == []
    assert datos["bajas_tardias"] == []
    assert "baja_tardia" not in acciones(db, ana)


def test_baja_dentro_de_las_2_horas_queda_como_baja_tardia(db, usuarios):
    _, ana, beto = usuarios
    partido = partido_en(db, usuarios, timedelta(hours=1))

    salir_partido(partido.id, ana, db)

    datos = datos_partido(partido)
    # The spot is still freed and the substitute takes it.
    assert nombres(datos["participantes"]) == ["beto"]
    # The organizer sees who left late, and the player's history says so.
    assert nombres(datos["bajas_tardias"]) == ["ana"]
    assert "baja_tardia" in acciones(db, ana)


def test_el_limite_es_exactamente_2_horas(db, usuarios):
    _, ana, _ = usuarios
    partido = partido_en(db, usuarios, timedelta(hours=2, minutes=5))
    salir_partido(partido.id, ana, db)
    assert datos_partido(partido)["bajas_tardias"] == []


def test_el_organizador_no_puede_darse_de_baja(db, usuarios):
    organizador, _, _ = usuarios
    partido = partido_en(db, usuarios, timedelta(hours=1))

    with pytest.raises(ErrorPartido) as error:
        salir_partido(partido.id, organizador, db)
    assert error.value.codigo == "ORGANIZADOR_NO_PUEDE_SALIR"
