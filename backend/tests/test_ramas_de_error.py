"""Ramas de error y casos límite del código agregado en el fork: lo que responde la API
cuando algo no existe o no está permitido, y los casos que los caminos felices de los
otros archivos de prueba nunca alcanzan."""
import logging
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.modules.analitica.service as analitica
from app.config import _url_base_datos
from app.database.connection import Base, get_db
from app.database.models import (
    Evento,
    Partido,
    PartidoParticipante,
    ResultadoPartido,
    Usuario,
)
from app.main import app
from app.modules.analitica.service import enviar_a_ga as enviar_a_ga_real
from app.modules.auth.service import current_user
from app.modules.cuenta.service import ANONIMO_EMAIL, eliminar_cuenta
from app.modules.partidos.resultado import (
    aceptar_equipos,
    confirmar_resultado,
    disputar_resultado,
    estado_validacion,
    partido_jugado,
    proponer_equipos,
    registrar_resultado,
)
from app.modules.partidos.schemas import DatosPartido, Reprogramacion
from app.modules.partidos.service import (
    ErrorPartido,
    bajas_tardias,
    crear_partido,
    es_baja_tardia,
    reconfirmar_partido,
    reprogramar_partido,
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
        for nombre in ("organizador", "ana", "beto", "carla")
    ]
    db.add_all(creados)
    db.commit()
    for usuario in creados:
        db.refresh(usuario)
    return creados


@pytest.fixture
def cliente(db, usuarios):
    actor = {"usuario": usuarios[0]}
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[current_user] = lambda: actor["usuario"]
    yield TestClient(app), actor
    app.dependency_overrides.clear()


def nuevo_partido(db, organizador, cupos=6, dias=1, nombre="Clásico"):
    return crear_partido(
        DatosPartido(
            nombre=nombre,
            cantidad_jugadores=cupos,
            ubicacion="Cancha central",
            fecha=datetime.now(timezone.utc) + timedelta(days=dias),
        ),
        organizador,
        db,
    )


@pytest.fixture
def partido(db, usuarios):
    """Partido futuro con ana, beto y carla como titulares."""
    organizador, ana, beto, carla = usuarios
    partido = nuevo_partido(db, organizador)
    for jugador in (ana, beto, carla):
        unirse_partido(partido.id, jugador, db)
    return partido


def jugar(db, partido):
    partido.fecha = datetime.now(timezone.utc) - timedelta(hours=2)
    db.commit()


def codigo(respuesta):
    return respuesta.json()["detail"]["codigo"]


# --- API: respuestas para partidos inexistentes y acciones fallidas ----------


def test_rutas_de_un_partido_que_no_existe_responden_404(cliente):
    http, _ = cliente
    assert http.delete("/api/partidos/999/salir").status_code == 404
    assert http.post("/api/partidos/999/reconfirmar").status_code == 404
    assert http.patch(
        "/api/partidos/999/reprogramar", json={"motivo": "Lluvia", "ubicacion": "Otra"}
    ).status_code == 404
    assert http.get("/api/partidos/999/validacion").status_code == 404


def test_reprogramar_responde_422_sin_motivo_y_409_si_hay_respuestas_pendientes(
    db, cliente, partido
):
    http, _ = cliente
    url = f"/api/partidos/{partido.id}/reprogramar"

    respuesta = http.patch(url, json={"motivo": "   ", "ubicacion": "Cancha norte"})
    assert respuesta.status_code == 422
    assert codigo(respuesta) == "MOTIVO_OBLIGATORIO"

    assert http.patch(url, json={"motivo": "Lluvia", "ubicacion": "Cancha norte"}).status_code == 200
    respuesta = http.patch(url, json={"motivo": "Otra vez", "ubicacion": "Cancha sur"})
    assert respuesta.status_code == 409
    assert codigo(respuesta) == "REPROGRAMACION_PENDIENTE"


def test_recorrido_de_validacion_por_la_api_con_sus_errores(db, cliente, usuarios, partido):
    http, actor = cliente
    organizador, ana, beto, carla = usuarios
    url = f"/api/partidos/{partido.id}"

    # Equipos: un capitán inválido es un error de datos (422).
    respuesta = http.put(f"{url}/equipos", json={"equipo_b": [beto.id], "capitan_rival_id": ana.id})
    assert respuesta.status_code == 422
    assert codigo(respuesta) == "EQUIPOS_INVALIDOS"
    respuesta = http.put(f"{url}/equipos", json={"equipo_b": [beto.id, carla.id], "capitan_rival_id": beto.id})
    assert respuesta.status_code == 200
    assert respuesta.json()["estado_validacion"] == "equipos_propuestos"

    # Solo el capitán acepta (403), y una sola vez (409).
    actor["usuario"] = ana
    assert codigo(http.post(f"{url}/equipos/aceptar")) == "SOLO_CAPITAN"
    actor["usuario"] = beto
    assert http.post(f"{url}/equipos/aceptar").json()["estado_validacion"] == "equipos_aceptados"
    respuesta = http.post(f"{url}/equipos/aceptar")
    assert respuesta.status_code == 409
    assert codigo(respuesta) == "EQUIPOS_YA_ACEPTADOS"

    # El marcador espera a que termine el partido (409).
    actor["usuario"] = organizador
    respuesta = http.post(f"{url}/resultados", json={"goles_a": 1, "goles_b": 0})
    assert respuesta.status_code == 409
    assert codigo(respuesta) == "PARTIDO_NO_TERMINADO"

    # Todavía no hay nada que disputar (409); tras el marcador, el capitán lo confirma.
    jugar(db, partido)
    actor["usuario"] = beto
    respuesta = http.post(f"{url}/resultados/disputar", json={"motivo": "Gol anulado"})
    assert respuesta.status_code == 409
    assert codigo(respuesta) == "SIN_RESULTADO_PENDIENTE"
    actor["usuario"] = organizador
    assert http.post(f"{url}/resultados", json={"goles_a": 2, "goles_b": 1}).status_code == 200
    actor["usuario"] = beto
    respuesta = http.post(f"{url}/resultados/confirmar")
    assert respuesta.status_code == 200
    assert respuesta.json()["estado_validacion"] == "resultado_confirmado"

    nombres = [e.evento for e in db.scalars(select(Evento).order_by(Evento.id))]
    assert "resultado_confirmado" in nombres
    assert nombres.count("tarea_fallida") >= 5


# --- Reglas del servicio que los caminos felices nunca alcanzan ---------------


def test_reconfirmar_un_partido_inexistente_o_sin_estar_inscrito(db, usuarios, partido):
    assert reconfirmar_partido(999, usuarios[1], db) is None
    with pytest.raises(ErrorPartido) as error:
        reconfirmar_partido(partido.id, usuarios[0], db)
    assert error.value.codigo == "NO_INSCRITO"


def test_reprogramar_exige_motivo_en_el_servicio(db, partido):
    with pytest.raises(ErrorPartido) as error:
        reprogramar_partido(partido, Reprogramacion(ubicacion="Otra", motivo=" "), db)
    assert error.value.codigo == "MOTIVO_OBLIGATORIO"


def test_un_partido_sin_fecha_no_tiene_baja_tardia_ni_se_considera_jugado(db, usuarios):
    sin_fecha = Partido(usuario_id=usuarios[0].id, nombre="Sin fecha", ubicacion="X")
    assert es_baja_tardia(sin_fecha) is False
    assert partido_jugado(sin_fecha) is False
    # Todavía no se guardó: no hay sesión, así que no hay bajas tardías que buscar.
    assert bajas_tardias(sin_fecha) == []
    assert estado_validacion(sin_fecha) == "sin_equipos"


def test_reglas_de_validacion_en_el_servicio(db, usuarios, partido):
    organizador, ana, beto, carla = usuarios
    assert aceptar_equipos(999, beto, db) is None
    assert confirmar_resultado(999, beto, db) is None
    assert disputar_resultado(999, beto, "x", db) is None

    with pytest.raises(ErrorPartido) as error:
        aceptar_equipos(partido.id, beto, db)
    assert error.value.codigo == "EQUIPOS_NO_PROPUESTOS"

    with pytest.raises(ErrorPartido) as error:
        proponer_equipos(partido, [], beto.id, db)
    assert error.value.codigo == "EQUIPOS_INVALIDOS"

    proponer_equipos(partido, [beto.id, carla.id], beto.id, db)
    aceptar_equipos(partido.id, beto, db)
    jugar(db, partido)
    with pytest.raises(ErrorPartido) as error:
        proponer_equipos(partido, [beto.id], beto.id, db)
    assert error.value.codigo == "PARTIDO_YA_JUGADO"
    with pytest.raises(ErrorPartido) as error:
        registrar_resultado(partido, -1, 0, db)
    assert error.value.codigo == "MARCADOR_INVALIDO"


# --- Eliminación de la cuenta: los casos menos comunes -----------------------


def test_eliminar_cuenta_en_partidos_sin_fecha_sin_resultado_y_como_capitan(db, usuarios):
    organizador, ana, beto, carla = usuarios
    # Un partido sin fecha cuenta como uno que todavía falta jugar.
    sin_fecha = Partido(usuario_id=organizador.id, nombre="Sin fecha", ubicacion="X", cantidad_jugadores=4)
    # Un partido jugado sin resultado confirmado: no se conserva nada.
    viejo = Partido(
        usuario_id=organizador.id, nombre="Viejo", ubicacion="X", cantidad_jugadores=4,
        fecha=datetime.now(timezone.utc) - timedelta(days=3),
    )
    db.add_all([sin_fecha, viejo])
    db.flush()
    db.add_all([
        PartidoParticipante(partido_id=sin_fecha.id, usuario_id=ana.id),
        PartidoParticipante(partido_id=viejo.id, usuario_id=ana.id),
    ])
    # Capitán rival de un partido futuro: se le quita la capitanía.
    futuro = nuevo_partido(db, organizador, nombre="Futuro")
    unirse_partido(futuro.id, ana, db)
    futuro.capitan_rival_id = ana.id
    futuro.equipos_aceptados = True
    db.commit()
    ids = (sin_fecha.id, viejo.id, futuro.id)

    eliminar_cuenta(ana, db)

    db.expire_all()
    restantes = db.scalars(select(PartidoParticipante)).all()
    assert [p for p in restantes if p.partido_id in ids] == []
    futuro = db.get(Partido, ids[2])
    assert futuro.capitan_rival_id is None
    assert futuro.equipos_aceptados is False


def test_si_el_titular_se_va_sin_suplentes_el_partido_vuelve_a_tener_cupo(db, usuarios):
    organizador, ana = usuarios[0], usuarios[1]
    partido = nuevo_partido(db, organizador, cupos=1)
    unirse_partido(partido.id, ana, db)
    assert partido.estado == "equipo completo"

    eliminar_cuenta(ana, db)

    db.expire_all()
    assert db.get(Partido, partido.id).estado == "cupos abiertos"


def test_dos_cuentas_eliminadas_del_mismo_resultado_quedan_como_un_solo_anonimo(db, usuarios):
    organizador, ana, beto, carla = usuarios
    jugado = Partido(
        usuario_id=organizador.id, nombre="Final", ubicacion="X", cantidad_jugadores=4,
        fecha=datetime.now(timezone.utc) - timedelta(days=1),
    )
    db.add(jugado)
    db.flush()
    db.add_all([
        PartidoParticipante(partido_id=jugado.id, usuario_id=ana.id),
        PartidoParticipante(partido_id=jugado.id, usuario_id=beto.id),
        ResultadoPartido(partido_id=jugado.id, version=1, goles_a=1, goles_b=0, estado="confirmado"),
    ])
    db.commit()

    eliminar_cuenta(ana, db)
    eliminar_cuenta(beto, db)

    db.expire_all()
    anonimo = db.scalar(select(Usuario).where(Usuario.email == ANONIMO_EMAIL))
    jugadores = [p.usuario_id for p in db.get(Partido, jugado.id).participantes]
    assert jugadores == [anonimo.id]


# --- Analítica: Google Analytics y fallos que no deben romper una petición ---


class _Hilo:
    """Ejecuta la llamada a GA de inmediato en lugar de en segundo plano."""

    def __init__(self, target, daemon):
        self.target = target

    def start(self):
        self.target()


class _Ajustes:
    ga_measurement_id = "G-PRUEBA"
    ga_api_secret = "secreto-de-prueba"


def test_enviar_a_ga_manda_el_evento_y_nunca_rompe_la_app(monkeypatch, caplog):
    enviados = []

    class _Respuesta:
        def close(self):
            enviados.append("cerrada")

    def abrir(peticion, timeout):
        enviados.append((peticion.full_url, peticion.data))
        return _Respuesta()

    monkeypatch.setattr(analitica, "settings", _Ajustes())
    monkeypatch.setattr(analitica.threading, "Thread", _Hilo)
    monkeypatch.setattr(analitica.urllib.request, "urlopen", abrir)

    enviar_a_ga_real("partido_unido", {"como_suplente": True, "deporte": "futbol"})
    url, cuerpo = enviados[0]
    assert "measurement_id=G-PRUEBA" in url
    # GA solo acepta texto y números: los booleanos se envían como "true"/"false".
    assert b'"como_suplente": "true"' in cuerpo
    assert enviados[1] == "cerrada"

    def fallar(peticion, timeout):
        raise OSError("sin red")

    monkeypatch.setattr(analitica.urllib.request, "urlopen", fallar)
    with caplog.at_level(logging.WARNING):
        enviar_a_ga_real("partido_unido", {})
    assert "No se pudo enviar partido_unido" in caplog.text


def test_sin_credenciales_de_ga_no_se_envia_nada(monkeypatch):
    class _SinGa:
        ga_measurement_id = ""
        ga_api_secret = ""

    monkeypatch.setattr(analitica, "settings", _SinGa())
    monkeypatch.setattr(analitica.threading, "Thread", lambda **_: pytest.fail("no debía enviar"))
    assert enviar_a_ga_real("partido_unido", {}) is None


def test_un_fallo_de_flujo_desconocido_se_guarda_como_otro(db):
    evento = analitica.track(db, analitica.TAREA_FALLIDA, {"flujo": "inventado", "motivo": "X"})
    assert evento.props == {"flujo": "otro", "motivo": "OTRO"}


def test_si_la_analitica_falla_la_peticion_sigue(caplog):
    class _BaseRota:
        def add(self, _):
            raise RuntimeError("sin base")

        def rollback(self):
            raise RuntimeError("sin base")

    with caplog.at_level(logging.WARNING):
        analitica.registrar(_BaseRota(), "partido_unido")
        analitica.registrar_fallo(_BaseRota(), "unirse", "YA_INSCRITO")
    assert "No se pudo registrar partido_unido" in caplog.text
    assert "No se pudo registrar el fallo de unirse" in caplog.text


# --- Configuración -----------------------------------------------------------


def test_la_url_de_la_nube_usa_el_driver_de_psycopg():
    assert _url_base_datos("postgres://u:p@host/db") == "postgresql+psycopg://u:p@host/db"
    assert _url_base_datos("postgresql://u:p@host/db") == "postgresql+psycopg://u:p@host/db"
    assert _url_base_datos("sqlite://") == "sqlite://"
