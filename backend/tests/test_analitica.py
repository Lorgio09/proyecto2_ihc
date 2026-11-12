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


def nombres_eventos(db):
    return [item.evento for item in eventos(db)]


def test_partido_unido_se_registra_solo_si_unirse_funciona(db, cliente, duelo):
    http, actor = cliente

    assert http.post(f"/api/partidos/{duelo.id}/unirse").status_code == 200
    # Same person again: the join fails, so no second success event...
    assert http.post(f"/api/partidos/{duelo.id}/unirse").status_code == 409

    guardados = eventos(db)
    assert [item.evento for item in guardados] == ["partido_unido", "tarea_fallida"]
    assert guardados[0].props == {"deporte": "basquet", "como_suplente": False}
    # ...but the failure is recorded with its reason from the fixed list.
    assert guardados[1].props == {"flujo": "unirse", "motivo": "YA_INSCRITO"}
    assert all(sin_datos_personales(item) for item in guardados)


def test_partido_unido_marca_cuando_entra_como_suplente(db, cliente, usuarios, duelo):
    http, actor = cliente
    http.post(f"/api/partidos/{duelo.id}/unirse")
    actor["usuario"] = usuarios[2]
    http.post(f"/api/partidos/{duelo.id}/unirse")

    assert [item.props["como_suplente"] for item in eventos(db)] == [False, True]


def test_crear_partido_registra_exito_y_fallo(db, cliente):
    http, _ = cliente
    datos = {"nombre": "Nuevo", "cantidad_jugadores": 4, "ubicacion": "Cancha"}
    futuro = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    pasado = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()

    assert http.post("/api/partidos", json={**datos, "fecha": futuro}).status_code == 201
    assert http.post("/api/partidos", json={**datos, "fecha": pasado}).status_code == 422

    guardados = eventos(db)
    assert [item.evento for item in guardados] == ["partido_creado", "tarea_fallida"]
    assert guardados[0].props == {"deporte": "futbol"}
    assert guardados[1].props == {"flujo": "crear_partido", "motivo": "FECHA_NO_FUTURA"}


def test_baja_registra_si_fue_tardia(db, cliente, usuarios):
    http, actor = cliente
    pronto = crear_partido(
        DatosPartido(
            nombre="En una hora",
            cantidad_jugadores=4,
            ubicacion="Coliseo",
            fecha=datetime.now(timezone.utc) + timedelta(hours=1),
        ),
        usuarios[0],
        db,
    )
    http.post(f"/api/partidos/{pronto.id}/unirse")
    assert http.delete(f"/api/partidos/{pronto.id}/salir").status_code == 200
    # The organizer cannot leave: a permission failure.
    actor["usuario"] = usuarios[0]
    assert http.delete(f"/api/partidos/{pronto.id}/salir").status_code == 409

    guardados = [item for item in eventos(db) if item.evento != "partido_unido"]
    assert [item.evento for item in guardados] == ["baja_registrada", "tarea_fallida"]
    assert guardados[0].props == {"tardia": True}
    assert guardados[1].props == {
        "flujo": "darse_de_baja",
        "motivo": "ORGANIZADOR_NO_PUEDE_SALIR",
    }


def test_reprogramar_registra_exito(db, cliente, usuarios, duelo):
    http, actor = cliente
    actor["usuario"] = usuarios[0]
    respuesta = http.patch(
        f"/api/partidos/{duelo.id}/reprogramar",
        json={"ubicacion": "Otra cancha", "motivo": "Lluvia"},
    )
    assert respuesta.status_code == 200
    assert nombres_eventos(db) == ["partido_reprogramado"]
    # The reason the organizer typed is never stored.
    assert "Lluvia" not in str(eventos(db)[0].props)


def test_busqueda_sin_resultados_guarda_solo_los_filtros_usados(db, cliente, duelo):
    http, _ = cliente
    assert http.get("/api/partidos/explorar", params={"busqueda": "zzz"}).json() == []
    assert http.get("/api/partidos/explorar").json() != []  # no filter: nothing

    guardados = eventos(db)
    assert [item.evento for item in guardados] == ["busqueda_sin_resultados"]
    assert guardados[0].props == {"filtros": "busqueda"}
    assert "zzz" not in str(guardados[0].props)


def test_la_app_no_puede_registrar_exitos_ni_propiedades_ajenas(db, cliente):
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
    # A failure reason outside the fixed list is stored as OTRO.
    http.post(
        "/api/analitica/eventos",
        json={
            "evento": "tarea_fallida",
            "props": {"flujo": "crear_partido", "motivo": "texto libre de ana"},
        },
    )
    guardados = eventos(db)
    assert guardados[0].props == {"deporte": "voley"}
    assert guardados[1].props == {"flujo": "crear_partido", "motivo": "OTRO"}


def test_panel_muestra_un_embudo_por_flujo_y_la_mayor_caida(db, cliente, duelo):
    http, _ = cliente
    for _ in range(4):
        http.post("/api/analitica/eventos", json={"evento": "union_iniciada"})
    http.post(f"/api/partidos/{duelo.id}/unirse")
    for _ in range(2):
        http.post("/api/analitica/eventos", json={"evento": "partido_creacion_iniciada"})

    resumen = http.get("/api/analitica/resumen").json()
    embudos = {embudo["flujo"]: embudo for embudo in resumen["embudos"]}
    assert set(embudos) == {
        "crear_partido", "unirse", "reprogramar", "validar_resultado", "darse_de_baja"
    }
    unirse = embudos["unirse"]
    assert [paso["cantidad"] for paso in unirse["pasos"]] == [4, 1]
    assert unirse["pasos"][1]["caida"] == 75
    assert unirse["termina"] == 25
    # Creating lost 100 % (2 started, none created): the biggest drop.
    assert resumen["mayor_caida"] == {
        "flujo": "crear_partido", "evento": "partido_creado", "caida": 100
    }

    panel = http.get("/analitica")
    assert panel.status_code == 200
    assert "Mayor caída" in panel.text
    assert "termina 25 %" in panel.text
