"""Tarea 10 · Eliminar la cuenta with UniSport's rule: a holder's spot in a
future match goes to the first substitute, and confirmed results stay but
anonymously. When the rule stops the deletion, the answer says why and what to do.
"""
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base, get_db
from app.database.models import (
    Evento,
    HistorialParticipacion,
    Partido,
    PartidoParticipante,
    ResultadoPartido,
    Usuario,
)
from app.main import app
from app.modules.auth.service import current_user, hash_password
from app.modules.cuenta.service import ANONIMO_EMAIL, ANONIMO_NOMBRE
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


def _usuario(db, nombre):
    usuario = Usuario(
        nombre=nombre,
        email=f"{nombre.lower()}@correo.com",
        password_hash=hash_password("Clave123"),
    )
    db.add(usuario)
    db.commit()
    return usuario


def _cliente(db, usuario):
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[current_user] = lambda: usuario
    return TestClient(app)


def _partido_jugado(db, organizador, nombre, estado_resultado, capitan=None):
    partido = Partido(
        usuario_id=organizador.id,
        nombre=nombre,
        cantidad_jugadores=4,
        ubicacion="Cancha",
        fecha=datetime.now(timezone.utc) - timedelta(days=2),
        estado="equipo completo",
        capitan_rival_id=capitan.id if capitan else None,
        equipos_aceptados=capitan is not None,
    )
    db.add(partido)
    db.flush()
    db.add(
        ResultadoPartido(
            partido_id=partido.id, version=1, goles_a=2, goles_b=1,
            estado=estado_resultado,
        )
    )
    db.commit()
    return partido


@pytest.fixture(autouse=True)
def limpiar_overrides():
    yield
    app.dependency_overrides.clear()


def _eventos(db, nombre):
    return db.scalars(select(Evento).where(Evento.evento == nombre)).all()


def test_titular_que_se_va_deja_su_lugar_al_primer_suplente(db):
    org, ana, beto, caro = (_usuario(db, n) for n in ("Org", "Ana", "Beto", "Caro"))
    manana = datetime.now(timezone.utc) + timedelta(days=1)
    partido = crear_partido(
        DatosPartido(nombre="Duelo", cantidad_jugadores=1, ubicacion="Cancha",
                     fecha=manana),
        org, db,
    )
    unirse_partido(partido.id, ana, db)                      # titular
    unirse_partido(partido.id, beto, db)  # full: first substitute
    unirse_partido(partido.id, caro, db)  # second substitute
    ana_id = ana.id

    previa = _cliente(db, ana).get("/api/cuenta/eliminacion").json()
    assert previa["puede_eliminar"] is True
    assert previa["consecuencias"]["partidos_futuros"] == 1
    assert previa["consecuencias"]["ascensos_de_suplentes"] == 1

    respuesta = _cliente(db, ana).delete("/api/cuenta")
    assert respuesta.status_code == 204

    db.expire_all()
    assert db.get(Usuario, ana_id) is None
    roles = {
        p.usuario.nombre: p.es_suplente
        for p in db.scalars(
            select(PartidoParticipante).where(PartidoParticipante.partido_id == partido.id)
        )
    }
    assert roles == {"Beto": False, "Caro": True}
    assert db.scalars(
        select(HistorialParticipacion).where(HistorialParticipacion.usuario_id == ana_id)
    ).all() == []
    assert len(_eventos(db, "cuenta_eliminada")) == 1


def test_resultado_confirmado_se_conserva_de_forma_anonima(db):
    ana, beto = _usuario(db, "Ana"), _usuario(db, "Beto")
    propio = _partido_jugado(db, ana, "Clásico de Ana", "confirmado", capitan=beto)
    ajeno = _partido_jugado(db, beto, "Clásico de Beto", "confirmado", capitan=ana)
    db.add(PartidoParticipante(partido_id=ajeno.id, usuario_id=ana.id, equipo="B"))
    sin_resultado = Partido(
        usuario_id=ana.id, nombre="Viejo sin resultado", cantidad_jugadores=4,
        ubicacion="Cancha", fecha=datetime.now(timezone.utc) - timedelta(days=9),
    )
    db.add(sin_resultado)
    db.commit()
    sin_resultado_id = sin_resultado.id

    assert _cliente(db, ana).delete("/api/cuenta").status_code == 204

    db.expire_all()
    anonimo = db.scalar(select(Usuario).where(Usuario.email == ANONIMO_EMAIL))
    assert anonimo.nombre == ANONIMO_NOMBRE
    # The matches and their scores stay; the person is replaced.
    assert db.get(Partido, propio.id).usuario_id == anonimo.id
    assert db.get(Partido, ajeno.id).capitan_rival_id == anonimo.id
    assert [r.estado for r in db.get(Partido, propio.id).resultados] == ["confirmado"]
    jugadores = [p.usuario_id for p in db.get(Partido, ajeno.id).participantes]
    assert jugadores == [anonimo.id]
    # Without a confirmed result there is nothing to keep.
    assert db.get(Partido, sin_resultado_id) is None


def test_despues_de_eliminarla_no_puede_iniciar_sesion(db):
    ana = _usuario(db, "Ana")
    http = _cliente(db, ana)
    assert http.post(
        "/api/auth/login", json={"email": "ana@correo.com", "password": "Clave123"}
    ).status_code == 200

    assert http.delete("/api/cuenta").status_code == 204

    assert http.post(
        "/api/auth/login", json={"email": "ana@correo.com", "password": "Clave123"}
    ).status_code == 401


def test_bloquea_si_organiza_un_partido_futuro_con_jugadores(db):
    ana, beto = _usuario(db, "Ana"), _usuario(db, "Beto")
    manana = datetime.now(timezone.utc) + timedelta(days=1)
    partido = crear_partido(
        DatosPartido(nombre="Fulbito de Ana", cantidad_jugadores=4,
                     ubicacion="Cancha", fecha=manana),
        ana, db,
    )
    unirse_partido(partido.id, beto, db)

    previa = _cliente(db, ana).get("/api/cuenta/eliminacion").json()
    assert previa["puede_eliminar"] is False
    assert previa["bloqueos"][0]["codigo"] == "ORGANIZA_PARTIDOS_CON_JUGADORES"

    respuesta = _cliente(db, ana).delete("/api/cuenta")
    assert respuesta.status_code == 409
    detalle = respuesta.json()["detail"]
    assert detalle["codigo"] == "ORGANIZA_PARTIDOS_CON_JUGADORES"
    # Says why (who is affected) and what to do.
    assert "Fulbito de Ana" in detalle["mensaje"]
    assert "Eliminar partido" in detalle["mensaje"]

    db.expire_all()
    assert db.get(Usuario, ana.id) is not None
    fallos = _eventos(db, "tarea_fallida")
    assert [f.props for f in fallos] == [
        {"flujo": "eliminar_cuenta", "motivo": "ORGANIZA_PARTIDOS_CON_JUGADORES"}
    ]


def test_bloquea_si_es_capitan_con_un_marcador_por_validar(db):
    ana, beto = _usuario(db, "Ana"), _usuario(db, "Beto")
    _partido_jugado(db, beto, "Clásico", "pendiente", capitan=ana)

    respuesta = _cliente(db, ana).delete("/api/cuenta")
    assert respuesta.status_code == 409
    detalle = respuesta.json()["detail"]
    assert detalle["codigo"] == "CAPITAN_CON_RESULTADO_PENDIENTE"
    assert "Clásico" in detalle["mensaje"]
    assert "Confírmalo o dispútalo" in detalle["mensaje"]


def test_organizador_sin_jugadores_puede_irse_y_su_partido_se_borra(db):
    ana = _usuario(db, "Ana")
    manana = datetime.now(timezone.utc) + timedelta(days=1)
    partido = crear_partido(
        DatosPartido(nombre="Vacío", cantidad_jugadores=4, ubicacion="Cancha",
                     fecha=manana),
        ana, db,
    )
    partido_id = partido.id

    previa = _cliente(db, ana).get("/api/cuenta/eliminacion").json()
    assert previa["consecuencias"]["partidos_organizados_eliminados"] == 1
    assert _cliente(db, ana).delete("/api/cuenta").status_code == 204
    db.expire_all()
    assert db.get(Partido, partido_id) is None


def test_la_app_puede_registrar_el_inicio_de_la_eliminacion(db):
    ana = _usuario(db, "Ana")
    http = _cliente(db, ana)
    assert http.post(
        "/api/analitica/eventos", json={"evento": "eliminacion_iniciada"}
    ).status_code < 300
    # The success comes only from the backend.
    assert http.post(
        "/api/analitica/eventos", json={"evento": "cuenta_eliminada"}
    ).status_code >= 400
