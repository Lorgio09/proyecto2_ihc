from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import PartidoParticipante, Usuario
from app.modules.partidos.schemas import (
    ActualizacionPartido,
    DatosPartido,
    Reprogramacion,
)
from app.modules.partidos.service import (
    ErrorPartido,
    actualizar_partido,
    crear_partido,
    datos_partido,
    reconfirmar_partido,
    reprogramar_partido,
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
        for nombre in ("organizador", "ana", "beto", "carla")
    ]
    db.add_all(creados)
    db.commit()
    for usuario in creados:
        db.refresh(usuario)
    return creados


@pytest.fixture
def partido(db, usuarios):
    """Two holder spots taken by ana and beto, carla waiting as substitute."""
    organizador, ana, beto, carla = usuarios
    partido = crear_partido(
        DatosPartido(
            nombre="Duelo de dos",
            cantidad_jugadores=2,
            ubicacion="Cancha central",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )
    for jugador in (ana, beto, carla):
        unirse_partido(partido.id, jugador, db)
    return partido


def nueva_fecha():
    return datetime.now(timezone.utc) + timedelta(days=3)


def nombres(lista):
    return [usuario.nombre for usuario in lista]


def test_reprogramar_cambia_datos_y_pide_reconfirmar_a_los_titulares(db, partido):
    reprogramar_partido(
        partido,
        Reprogramacion(
            fecha=nueva_fecha(),
            ubicacion="Coliseo",
            motivo="La cancha está en mantenimiento",
        ),
        db,
    )

    datos = datos_partido(partido)
    assert datos["ubicacion"] == "Coliseo"
    assert datos["motivo_reprogramacion"] == "La cancha está en mantenimiento"
    # Holders keep their spot while they answer; the substitute is not asked.
    assert nombres(datos["participantes"]) == ["ana", "beto"]
    assert nombres(datos["pendientes_confirmar"]) == ["ana", "beto"]
    assert nombres(datos["suplentes"]) == ["carla"]


def test_un_titular_acepta_otro_se_retira_y_asciende_el_primer_suplente(
    db, usuarios, partido
):
    _, ana, beto, carla = usuarios
    reprogramar_partido(
        partido,
        Reprogramacion(fecha=nueva_fecha(), motivo="Lluvia"),
        db,
    )

    reconfirmar_partido(partido.id, ana, db)
    salir_partido(partido.id, beto, db)

    datos = datos_partido(partido)
    assert nombres(datos["participantes"]) == ["ana", "carla"]
    assert datos["suplentes"] == []
    assert datos["pendientes_confirmar"] == []
    # Never over capacity and nobody listed twice.
    assert datos["cantidad_participantes"] == partido.cantidad_jugadores
    inscripciones = db.scalars(
        select(PartidoParticipante.usuario_id).where(
            PartidoParticipante.partido_id == partido.id
        )
    ).all()
    assert len(inscripciones) == len(set(inscripciones)) == 2


def test_no_se_puede_reprogramar_otra_vez_con_respuestas_pendientes(
    db, usuarios, partido
):
    _, ana, beto, _ = usuarios
    reprogramar_partido(partido, Reprogramacion(fecha=nueva_fecha(), motivo="Lluvia"), db)

    with pytest.raises(ErrorPartido) as error:
        reprogramar_partido(
            partido,
            Reprogramacion(ubicacion="Otra cancha", motivo="Cambio de nuevo"),
            db,
        )
    assert error.value.codigo == "REPROGRAMACION_PENDIENTE"

    reconfirmar_partido(partido.id, ana, db)
    reconfirmar_partido(partido.id, beto, db)
    reprogramar_partido(
        partido,
        Reprogramacion(ubicacion="Otra cancha", motivo="Cambio de nuevo"),
        db,
    )
    assert partido.ubicacion == "Otra cancha"


def test_editar_fecha_tambien_se_bloquea_con_respuestas_pendientes(db, partido):
    reprogramar_partido(partido, Reprogramacion(fecha=nueva_fecha(), motivo="Lluvia"), db)

    with pytest.raises(ErrorPartido) as error:
        actualizar_partido(
            partido,
            ActualizacionPartido(fecha=nueva_fecha() + timedelta(days=1)),
            db,
        )
    assert error.value.codigo == "REPROGRAMACION_PENDIENTE"


def test_reprogramar_sin_cambios_o_con_fecha_pasada_se_rechaza(db, partido):
    with pytest.raises(ErrorPartido) as sin_cambios:
        reprogramar_partido(
            partido,
            Reprogramacion(ubicacion="Cancha central", motivo="Nada cambia"),
            db,
        )
    assert sin_cambios.value.codigo == "SIN_CAMBIOS"

    with pytest.raises(ErrorPartido) as pasada:
        reprogramar_partido(
            partido,
            Reprogramacion(
                fecha=datetime.now(timezone.utc) - timedelta(days=1),
                motivo="Fecha pasada",
            ),
            db,
        )
    assert pasada.value.codigo == "FECHA_NO_FUTURA"
    assert datos_partido(partido)["pendientes_confirmar"] == []


def test_reconfirmar_sin_reprogramacion_pendiente_se_rechaza(db, usuarios, partido):
    _, ana, _, carla = usuarios

    with pytest.raises(ErrorPartido) as error:
        reconfirmar_partido(partido.id, ana, db)
    assert error.value.codigo == "SIN_RECONFIRMACION"

    reprogramar_partido(partido, Reprogramacion(fecha=nueva_fecha(), motivo="Lluvia"), db)
    # The substitute was not asked to reconfirm.
    with pytest.raises(ErrorPartido):
        reconfirmar_partido(partido.id, carla, db)
