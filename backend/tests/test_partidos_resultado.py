from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import Usuario
from app.modules.partidos.resultado import (
    aceptar_equipos,
    confirmar_resultado,
    datos_validacion,
    disputar_resultado,
    listar_partidos_participando,
    proponer_equipos,
    registrar_resultado,
)
from app.modules.partidos.schemas import DatosPartido
from app.modules.partidos.service import ErrorPartido, crear_partido, unirse_partido


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
        for nombre in ("organizador", "ana", "beto", "carla")
    ]
    db.add_all(creados)
    db.commit()
    for usuario in creados:
        db.refresh(usuario)
    return creados


@pytest.fixture
def partido(db, usuarios):
    """Future match with ana, beto and carla as holders."""
    organizador, ana, beto, carla = usuarios
    partido = crear_partido(
        DatosPartido(
            nombre="Clásico",
            cantidad_jugadores=6,
            ubicacion="Cancha central",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )
    for jugador in (ana, beto, carla):
        unirse_partido(partido.id, jugador, db)
    return partido


def jugar(db, partido):
    """Move the match to the past, as if it had already been played."""
    partido.fecha = datetime.now(timezone.utc) - timedelta(hours=2)
    db.commit()


@pytest.fixture
def partido_jugado(db, usuarios, partido):
    """Played match: ana in team A, beto (captain) and carla in team B, accepted."""
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    aceptar_equipos(partido.id, beto, db)
    jugar(db, partido)
    return partido


def codigo(error_info):
    return error_info.value.codigo


# --- S1: teams proposed by the organizer, accepted by the rival captain ---


def test_proponer_equipos_deja_al_capitan_pendiente_de_aceptar(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)

    datos = datos_validacion(partido, organizador)
    assert datos["estado_validacion"] == "equipos_propuestos"
    assert [u.nombre for u in datos["equipo_a"]] == ["ana"]
    assert [u.nombre for u in datos["equipo_b"]] == ["beto", "carla"]
    assert datos["capitan_rival"].nombre == "beto"
    assert datos["equipos_aceptados"] is False


def test_el_capitan_acepta_los_equipos_antes_del_partido(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    aceptar_equipos(partido.id, beto, db)

    datos = datos_validacion(partido, beto)
    assert datos["estado_validacion"] == "equipos_aceptados"
    assert datos["es_capitan"] is True


def test_el_capitan_debe_estar_en_el_equipo_rival(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    with pytest.raises(ErrorPartido) as error:
        proponer_equipos(partido, [beto.id], ana.id, db)
    assert codigo(error) == "EQUIPOS_INVALIDOS"


def test_solo_el_capitan_acepta_los_equipos(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    with pytest.raises(ErrorPartido) as error:
        aceptar_equipos(partido.id, carla, db)
    assert codigo(error) == "SOLO_CAPITAN"


def test_no_se_aceptan_equipos_despues_del_partido(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    jugar(db, partido)
    with pytest.raises(ErrorPartido) as error:
        aceptar_equipos(partido.id, beto, db)
    assert codigo(error) == "PARTIDO_YA_JUGADO"


def test_cambiar_los_equipos_exige_nueva_aceptacion(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    aceptar_equipos(partido.id, beto, db)
    proponer_equipos(partido, [beto.id], beto.id, db)

    assert datos_validacion(partido, organizador)["equipos_aceptados"] is False


# --- S2-S4: result -> dispute -> correction -> confirmation ---


def test_recorrido_resultado_disputa_correccion_confirmacion(db, usuarios, partido_jugado):
    organizador, ana, beto, carla = usuarios

    registrar_resultado(partido_jugado, 3, 2, db)
    datos = datos_validacion(partido_jugado, beto)
    assert datos["estado_validacion"] == "resultado_pendiente"
    assert datos["resultado_definitivo"] is None

    disputar_resultado(partido_jugado.id, beto, "El tercer gol fue en fuera de juego", db)
    datos = datos_validacion(partido_jugado, organizador)
    assert datos["estado_validacion"] == "resultado_disputado"
    assert datos["resultado_definitivo"] is None

    registrar_resultado(partido_jugado, 2, 2, db)
    datos = datos_validacion(partido_jugado, beto)
    assert datos["estado_validacion"] == "resultado_pendiente"
    assert datos["resultado_definitivo"] is None

    confirmar_resultado(partido_jugado.id, beto, db)
    datos = datos_validacion(partido_jugado, organizador)
    assert datos["estado_validacion"] == "resultado_confirmado"
    assert datos["resultado_definitivo"] == {"goles_a": 2, "goles_b": 2}

    # The whole history is kept, newest first.
    historial = [
        (r["version"], r["goles_a"], r["goles_b"], r["estado"], r["motivo_disputa"])
        for r in datos["resultados"]
    ]
    assert historial == [
        (2, 2, 2, "confirmado", None),
        (1, 3, 2, "disputado", "El tercer gol fue en fuera de juego"),
    ]


def test_no_se_registra_el_marcador_antes_de_terminar(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    aceptar_equipos(partido.id, beto, db)
    with pytest.raises(ErrorPartido) as error:
        registrar_resultado(partido, 1, 0, db)
    assert codigo(error) == "PARTIDO_NO_TERMINADO"


def test_no_se_registra_el_marcador_sin_equipos_aceptados(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    jugar(db, partido)
    with pytest.raises(ErrorPartido) as error:
        registrar_resultado(partido, 1, 0, db)
    assert codigo(error) == "EQUIPOS_SIN_ACEPTAR"


def test_no_se_registra_otro_marcador_mientras_uno_espera_validacion(db, partido_jugado):
    registrar_resultado(partido_jugado, 1, 0, db)
    with pytest.raises(ErrorPartido) as error:
        registrar_resultado(partido_jugado, 2, 0, db)
    assert codigo(error) == "RESULTADO_PENDIENTE"


def test_el_resultado_confirmado_es_definitivo(db, usuarios, partido_jugado):
    organizador, ana, beto, carla = usuarios
    registrar_resultado(partido_jugado, 1, 0, db)
    confirmar_resultado(partido_jugado.id, beto, db)
    with pytest.raises(ErrorPartido) as error:
        registrar_resultado(partido_jugado, 5, 0, db)
    assert codigo(error) == "RESULTADO_CONFIRMADO"
    with pytest.raises(ErrorPartido) as error:
        disputar_resultado(partido_jugado.id, beto, "Cambié de opinión", db)
    assert codigo(error) == "SIN_RESULTADO_PENDIENTE"


def test_solo_el_capitan_confirma_o_disputa(db, usuarios, partido_jugado):
    organizador, ana, beto, carla = usuarios
    registrar_resultado(partido_jugado, 1, 0, db)
    for actor in (organizador, ana, carla):
        with pytest.raises(ErrorPartido) as error:
            confirmar_resultado(partido_jugado.id, actor, db)
        assert codigo(error) == "SOLO_CAPITAN"
        with pytest.raises(ErrorPartido) as error:
            disputar_resultado(partido_jugado.id, actor, "No", db)
        assert codigo(error) == "SOLO_CAPITAN"


def test_la_disputa_exige_motivo(db, usuarios, partido_jugado):
    organizador, ana, beto, carla = usuarios
    registrar_resultado(partido_jugado, 1, 0, db)
    with pytest.raises(ErrorPartido) as error:
        disputar_resultado(partido_jugado.id, beto, "   ", db)
    assert codigo(error) == "MOTIVO_OBLIGATORIO"


def test_no_se_cambian_los_equipos_con_un_resultado_registrado(db, usuarios, partido_jugado):
    organizador, ana, beto, carla = usuarios
    registrar_resultado(partido_jugado, 1, 0, db)
    with pytest.raises(ErrorPartido) as error:
        proponer_equipos(partido_jugado, [carla.id], carla.id, db)
    assert codigo(error) in ("PARTIDO_YA_JUGADO", "EQUIPOS_BLOQUEADOS")


# --- Played matches stay reachable for their participants ---


def test_mis_partidos_unidos_incluye_los_ya_jugados(db, usuarios, partido_jugado):
    organizador, ana, beto, carla = usuarios
    ids = [p.id for p in listar_partidos_participando(beto, db)]
    assert ids == [partido_jugado.id]
    assert listar_partidos_participando(organizador, db) == []


# --- HTTP contract: permission errors are 403, state errors 409 ---


def test_api_rechaza_con_403_a_quien_no_es_capitan(db, usuarios, partido_jugado):
    from fastapi.testclient import TestClient

    from app.database.connection import get_db
    from app.main import app
    from app.modules.auth.service import current_user

    organizador, ana, beto, carla = usuarios
    actor = {"usuario": organizador}
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[current_user] = lambda: actor["usuario"]
    try:
        cliente = TestClient(app)
        url = f"/api/partidos/{partido_jugado.id}"

        respuesta = cliente.post(f"{url}/resultados", json={"goles_a": 3, "goles_b": 1})
        assert respuesta.status_code == 200
        assert respuesta.json()["estado_validacion"] == "resultado_pendiente"

        # The organizer cannot validate the score they registered.
        respuesta = cliente.post(f"{url}/resultados/confirmar")
        assert respuesta.status_code == 403
        assert respuesta.json()["detail"]["codigo"] == "SOLO_CAPITAN"

        # A teammate of the captain cannot register a score.
        actor["usuario"] = carla
        respuesta = cliente.post(f"{url}/resultados", json={"goles_a": 0, "goles_b": 0})
        assert respuesta.status_code == 403
        assert respuesta.json()["detail"]["codigo"] == "SOLO_ORGANIZADOR"

        actor["usuario"] = beto
        respuesta = cliente.post(f"{url}/resultados/disputar", json={"motivo": "Gol anulado"})
        assert respuesta.status_code == 200
        datos = cliente.get(f"{url}/validacion").json()
        assert datos["estado_validacion"] == "resultado_disputado"
        assert datos["resultados"][0]["motivo_disputa"] == "Gol anulado"
        assert datos["resultado_definitivo"] is None
    finally:
        app.dependency_overrides.clear()
