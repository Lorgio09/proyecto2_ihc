from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database.connection import Base
from app.database.models import HistorialParticipacion, Usuario
from app.modules.partidos.schemas import ActualizacionPartido, DatosPartido
from app.modules.partidos.service import (
    ErrorPartido,
    actualizar_partido,
    completar_equipo,
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
        for nombre in ("organizador", "ana", "beto", "carla", "dario")
    ]
    db.add_all(creados)
    db.commit()
    for usuario in creados:
        db.refresh(usuario)
    return creados


@pytest.fixture
def partido(db, usuarios):
    """A match for two players, already filled by ana and beto."""
    organizador, ana, beto, _, _ = usuarios
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
    unirse_partido(partido.id, ana, db)
    unirse_partido(partido.id, beto, db)
    return partido


def nombres(lista):
    return [usuario.nombre for usuario in lista]


def acciones(db, usuario):
    return [
        evento.accion
        for evento in db.scalars(
            select(HistorialParticipacion)
            .where(HistorialParticipacion.usuario_id == usuario.id)
            .order_by(HistorialParticipacion.id)
        )
    ]


def test_con_el_cupo_lleno_quien_se_une_queda_como_suplente(db, usuarios, partido):
    carla = usuarios[3]

    unirse_partido(partido.id, carla, db)
    datos = datos_partido(partido)

    assert nombres(datos["participantes"]) == ["ana", "beto"]
    assert nombres(datos["suplentes"]) == ["carla"]
    assert datos["cantidad_participantes"] == 2
    assert datos["cantidad_suplentes"] == 1
    assert datos["cupos_disponibles"] == 0
    assert partido.estado == "equipo completo"
    assert acciones(db, carla) == ["se_unio_suplente"]


def test_los_suplentes_se_ordenan_por_llegada(db, usuarios, partido):
    _, _, _, carla, dario = usuarios

    unirse_partido(partido.id, dario, db)
    unirse_partido(partido.id, carla, db)

    assert nombres(datos_partido(partido)["suplentes"]) == ["dario", "carla"]


def test_si_sale_un_titular_sube_el_primer_suplente(db, usuarios, partido):
    _, ana, _, carla, dario = usuarios
    unirse_partido(partido.id, carla, db)
    unirse_partido(partido.id, dario, db)

    salir_partido(partido.id, ana, db)
    datos = datos_partido(partido)

    assert nombres(datos["participantes"]) == ["beto", "carla"]
    assert nombres(datos["suplentes"]) == ["dario"]
    assert datos["cupos_disponibles"] == 0
    assert partido.estado == "equipo completo"
    assert acciones(db, carla) == ["se_unio_suplente", "paso_a_titular"]
    assert acciones(db, dario) == ["se_unio_suplente"]
    assert acciones(db, ana) == ["se_unio"]


def test_si_sale_un_suplente_nadie_sube(db, usuarios, partido):
    _, _, _, carla, dario = usuarios
    unirse_partido(partido.id, carla, db)
    unirse_partido(partido.id, dario, db)

    salir_partido(partido.id, carla, db)
    datos = datos_partido(partido)

    assert nombres(datos["participantes"]) == ["ana", "beto"]
    assert nombres(datos["suplentes"]) == ["dario"]
    assert partido.estado == "equipo completo"
    assert acciones(db, carla) == ["se_unio_suplente"]


def test_si_sale_un_titular_sin_suplentes_se_abre_un_cupo(db, usuarios, partido):
    ana = usuarios[1]

    salir_partido(partido.id, ana, db)
    datos = datos_partido(partido)

    assert nombres(datos["participantes"]) == ["beto"]
    assert datos["suplentes"] == []
    assert datos["cupos_disponibles"] == 1
    assert partido.estado == "cupos abiertos"


def test_un_suplente_no_puede_unirse_dos_veces(db, usuarios, partido):
    carla = usuarios[3]
    unirse_partido(partido.id, carla, db)

    with pytest.raises(ErrorPartido) as error:
        unirse_partido(partido.id, carla, db)

    assert error.value.codigo == "YA_INSCRITO"


def test_equipo_cerrado_por_el_organizador_con_lugares_libres_rechaza(
    db, usuarios
):
    organizador, ana, _, carla, _ = usuarios
    partido = crear_partido(
        DatosPartido(
            nombre="Cerrado",
            cantidad_jugadores=3,
            ubicacion="Cancha central",
            fecha=datetime.now(timezone.utc) + timedelta(days=1),
        ),
        organizador,
        db,
    )
    unirse_partido(partido.id, ana, db)
    completar_equipo(partido, db)

    with pytest.raises(ErrorPartido) as error:
        unirse_partido(partido.id, carla, db)

    assert error.value.codigo == "EQUIPO_COMPLETO"
    assert datos_partido(partido)["suplentes"] == []


def test_subir_la_capacidad_promueve_a_los_suplentes(db, usuarios, partido):
    _, _, _, carla, dario = usuarios
    unirse_partido(partido.id, carla, db)
    unirse_partido(partido.id, dario, db)

    actualizar_partido(
        partido, ActualizacionPartido(cantidad_jugadores=3), db
    )
    datos = datos_partido(partido)

    assert nombres(datos["participantes"]) == ["ana", "beto", "carla"]
    assert nombres(datos["suplentes"]) == ["dario"]
    assert acciones(db, carla) == ["se_unio_suplente", "paso_a_titular"]


def test_la_capacidad_solo_se_compara_con_los_titulares(db, usuarios, partido):
    carla = usuarios[3]
    unirse_partido(partido.id, carla, db)

    with pytest.raises(ErrorPartido) as error:
        actualizar_partido(
            partido, ActualizacionPartido(cantidad_jugadores=1), db
        )

    assert error.value.codigo == "CAPACIDAD_INSUFICIENTE"
