from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base, get_db
from app.database.models import Evento, Usuario
from app.main import app
from app.modules.auth.service import current_user
from app.modules.partidos.schemas import DatosPartido
from app.modules.partidos.service import crear_partido


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


@pytest.fixture
def cliente(db, usuarios):
    actor = {"usuario": usuarios[1]}
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[current_user] = lambda: actor["usuario"]
    yield TestClient(app), actor
    app.dependency_overrides.clear()


@pytest.fixture
def duelo(db, usuarios):
    return crear_partido(
        DatosPartido(
            nombre="Duelo de uno",
            deporte="basquet",
            cantidad_jugadores=1,
            ubicacion="Coliseo",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        usuarios[0],
        db,
    )


def eventos(db):
    return db.scalars(select(Evento).order_by(Evento.id)).all()


def sin_datos_personales(evento: Evento):
    texto = str(evento.props).lower()
    return "@" not in texto and "ana" not in texto and "beto" not in texto


def test_union_iniciada_se_registra_una_vez_con_sus_propiedades(
    db, cliente, sin_google_analytics
):
    http, _ = cliente
    respuesta = http.post(
        "/api/analitica/eventos",
        json={"evento": "union_iniciada", "props": {"deporte": "futbol"}},
    )

    assert respuesta.status_code == 201
    guardados = eventos(db)
    assert len(guardados) == 1
    assert guardados[0].evento == "union_iniciada"
    assert guardados[0].props == {"deporte": "futbol"}
    assert sin_datos_personales(guardados[0])
    assert sin_google_analytics == [("union_iniciada", {"deporte": "futbol"})]


def test_partido_unido_se_registra_solo_si_unirse_funciona(db, cliente, duelo):
    http, actor = cliente

    assert http.post(f"/api/partidos/{duelo.id}/unirse").status_code == 200
    # Same person again: the join fails, so no success event.
    assert http.post(f"/api/partidos/{duelo.id}/unirse").status_code == 409

    guardados = eventos(db)
    assert [item.evento for item in guardados] == ["partido_unido"]
    assert guardados[0].props == {"deporte": "basquet", "como_suplente": False}
    assert sin_datos_personales(guardados[0])


def test_partido_unido_marca_cuando_entra_como_suplente(db, cliente, usuarios, duelo):
    http, actor = cliente
    http.post(f"/api/partidos/{duelo.id}/unirse")
    actor["usuario"] = usuarios[2]
    http.post(f"/api/partidos/{duelo.id}/unirse")

    assert [item.props["como_suplente"] for item in eventos(db)] == [False, True]


def test_la_app_no_puede_registrar_otros_eventos_ni_propiedades(db, cliente):
    http, _ = cliente
    respuesta = http.post("/api/analitica/eventos", json={"evento": "partido_unido"})
    assert respuesta.status_code == 422

    http.post(
        "/api/analitica/eventos",
        json={
            "evento": "union_iniciada",
            "props": {"deporte": "voley", "email": "ana@test.com"},
        },
    )
    assert eventos(db)[0].props == {"deporte": "voley"}


def test_panel_cuenta_eventos_y_porcentaje_que_termina(db, cliente, duelo):
    http, _ = cliente
    for _ in range(2):
        http.post("/api/analitica/eventos", json={"evento": "union_iniciada"})
    http.post(f"/api/partidos/{duelo.id}/unirse")

    resumen = http.get("/api/analitica/resumen").json()
    assert resumen["union_iniciada"] == 2
    assert resumen["partido_unido"] == 1
    assert resumen["porcentaje_termina"] == 50

    panel = http.get("/analitica")
    assert panel.status_code == 200
    assert "50 %" in panel.text
