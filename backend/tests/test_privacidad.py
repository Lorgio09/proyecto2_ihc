"""Clase 22 · Patrones oscuros: datos expuestos sin necesidad.

Para ver un partido solo hacen falta los nombres de los jugadores. Sus emails no deben
viajar en ninguna respuesta sobre partidos, aunque la app no los muestre.
"""
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
    """Un partido de un organizador con un jugador inscrito; un desconocido lo mira."""
    organizador, jugador, desconocido = [
        Usuario(nombre=nombre, email=f"{nombre}@correo.com", password_hash="x")
        for nombre in ("organizador", "jugador", "desconocido")
    ]
    db.add_all([organizador, jugador, desconocido])
    db.commit()
    partido = crear_partido(
        DatosPartido(
            nombre="Fulbito",
            cantidad_jugadores=10,
            ubicacion="Cancha central",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )
    unirse_partido(partido.id, jugador, db)

    actor = {"usuario": desconocido}
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[current_user] = lambda: actor["usuario"]
    yield TestClient(app), actor, partido, organizador, jugador
    app.dependency_overrides.clear()


def test_explorar_no_expone_el_email_de_nadie(escenario):
    http, _, partido, _, _ = escenario

    lista = http.get("/api/partidos/explorar")
    detalle = http.get(f"/api/partidos/explorar/{partido.id}")

    assert lista.status_code == detalle.status_code == 200
    # Los nombres siguen ahí: es lo que necesita la pantalla.
    assert lista.json()[0]["organizador"]["nombre"] == "organizador"
    assert lista.json()[0]["participantes"][0]["nombre"] == "jugador"
    # Ningún email del organizador ni de los jugadores le llega a un desconocido.
    assert "@" not in lista.text
    assert "@" not in detalle.text


def test_ni_el_organizador_ni_los_jugadores_reciben_emails(escenario):
    http, actor, partido, organizador, jugador = escenario

    actor["usuario"] = organizador
    assert "@" not in http.get("/api/partidos").text
    assert "@" not in http.get(f"/api/partidos/{partido.id}").text

    actor["usuario"] = jugador
    assert "@" not in http.get("/api/partidos/participando").text
