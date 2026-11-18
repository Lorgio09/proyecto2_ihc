"""Tarea 10 · Mis datos: una persona puede ver todo lo que UniSport guarda sobre ella,
y solo eso (nunca datos de otros jugadores, contraseñas ni tokens)."""
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base, get_db
from app.database.models import Usuario
from app.main import app
from app.modules.auth.service import current_user
from app.modules.partidos.schemas import DatosPartido
from app.modules.partidos.service import crear_partido, unirse_partido


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
def escenario(db):
    ana = Usuario(
        nombre="Ana",
        email="ana@correo.com",
        password_hash="hash-secreto",
        telefono="70000001",
        token_recuperacion="123456",
    )
    beto = Usuario(nombre="Beto", email="beto@correo.com", password_hash="x")
    db.add_all([ana, beto])
    db.commit()
    manana = datetime.now(timezone.utc) + timedelta(days=1)
    propio = crear_partido(
        DatosPartido(nombre="Partido de Ana", cantidad_jugadores=4,
                     ubicacion="Cancha A", fecha=manana),
        ana, db,
    )
    unirse_partido(propio.id, beto, db)
    ajeno = crear_partido(
        DatosPartido(nombre="Partido de Beto", cantidad_jugadores=4,
                     ubicacion="Cancha B", fecha=manana),
        beto, db,
    )
    unirse_partido(ajeno.id, ana, db)

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[current_user] = lambda: ana
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_mis_datos_trae_perfil_partidos_participaciones_e_historial(escenario):
    datos = escenario.get("/api/cuenta/mis-datos").json()

    assert datos["cuenta"] == {
        "nombre": "Ana", "email": "ana@correo.com", "telefono": "70000001"
    }
    assert [p["nombre"] for p in datos["partidos_organizados"]] == ["Partido de Ana"]
    assert [(p["partido"], p["rol"]) for p in datos["participaciones"]] == [
        ("Partido de Beto", "titular")
    ]
    assert [(h["accion"], h["partido"]) for h in datos["historial"]] == [
        ("se_unio", "Partido de Beto")
    ]


def test_mis_datos_no_incluye_datos_ajenos_ni_secretos(escenario):
    texto = escenario.get("/api/cuenta/mis-datos").text

    # Otras personas: Beto juega en el partido de Ana y organiza el otro.
    assert "Beto" not in texto.replace("Partido de Beto", "")
    assert "beto@correo.com" not in texto
    # Datos secretos.
    assert "hash-secreto" not in texto
    assert "123456" not in texto
