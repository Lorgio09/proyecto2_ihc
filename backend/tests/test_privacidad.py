"""Clase 22 · Patrones oscuros: datos expuestos sin necesidad.

Seeing a match only needs the players' names. Their email addresses must not
travel in any response about matches, not even if the app does not show them.
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
    """An organizer's match with one player in; a stranger looks at it."""
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
    # The names are still there: that is what the screen needs.
    assert lista.json()[0]["organizador"]["nombre"] == "organizador"
    assert lista.json()[0]["participantes"][0]["nombre"] == "jugador"
    # No email of the organizer or the players reaches a stranger.
    assert "@" not in lista.text
    assert "@" not in detalle.text


def test_ni_el_organizador_ni_los_jugadores_reciben_emails(escenario):
    http, actor, partido, organizador, jugador = escenario

    actor["usuario"] = organizador
    assert "@" not in http.get("/api/partidos").text
    assert "@" not in http.get(f"/api/partidos/{partido.id}").text

    actor["usuario"] = jugador
    assert "@" not in http.get("/api/partidos/participando").text
