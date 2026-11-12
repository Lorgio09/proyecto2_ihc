"""juan. Aqui estan los servicios para hacer un crud, crea, actualiza, edita y elimina los partidoss"""
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import exists, func, select
from sqlalchemy.orm import Session, object_session, selectinload

from app.database.models import HistorialParticipacion, Partido, PartidoParticipante, Usuario
from app.modules.partidos.schemas import (
    ActualizacionPartido,
    DatosPartido,
    Reprogramacion,
)


# A player may leave freely until this long before kick-off; later it counts
# as a late withdrawal ("baja tardía") that the organizer can see.
PLAZO_BAJA = timedelta(hours=2)


class ErrorPartido(ValueError):
    def __init__(self, codigo: str, mensaje: str):
        self.codigo = codigo
        self.mensaje = mensaje
        super().__init__(mensaje)


def validar_fecha_futura(fecha: datetime | None) -> datetime:
    if fecha is None:
        raise ErrorPartido(
            "FECHA_NO_FUTURA",
            "El partido debe tener una fecha futura",
        )

    fecha_normalizada = fecha
    if fecha_normalizada.tzinfo is None:
        fecha_normalizada = fecha_normalizada.replace(tzinfo=timezone.utc)
    if fecha_normalizada <= datetime.now(timezone.utc):
        raise ErrorPartido(
            "FECHA_NO_FUTURA",
            "El partido debe tener una fecha futura",
        )
    return fecha_normalizada


def buscar_partido(partido_id: int, usuario: Usuario, base_datos: Session) -> Partido | None:
    return base_datos.scalar(
        select(Partido)
        .where(Partido.id == partido_id, Partido.usuario_id == usuario.id)
        .options(
            selectinload(Partido.participantes).selectinload(
                PartidoParticipante.usuario
            )
        )
    )


def buscar_partido_publico(partido_id: int, base_datos: Session) -> Partido | None:
    return base_datos.scalar(
        select(Partido)
        .where(Partido.id == partido_id)
        .options(
            selectinload(Partido.usuario),
            selectinload(Partido.participantes).selectinload(
                PartidoParticipante.usuario
            ),
        )
    )


def crear_partido(datos: DatosPartido, usuario: Usuario, base_datos: Session) -> Partido:
    fecha = validar_fecha_futura(datos.fecha)
    partido = Partido(
        usuario_id=usuario.id,
        nombre=datos.nombre.strip(),
        cantidad_jugadores=datos.cantidad_jugadores,
        ubicacion=datos.ubicacion.strip(),
        tiempo_min=datos.tiempo_min.strip() if datos.tiempo_min else None,
        fecha=fecha,

        deporte=datos.deporte.strip(),
    )
    base_datos.add(partido)
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def listar_partidos(usuario: Usuario, base_datos: Session) -> list[Partido]:
    return list(
        base_datos.scalars(
            select(Partido)
            .where(Partido.usuario_id == usuario.id)
            .order_by(Partido.fecha, Partido.id)
            .options(
                selectinload(Partido.participantes).selectinload(
                    PartidoParticipante.usuario
                )
            )
        ).all()
    )

def listar_historial(
    usuario: Usuario,
    base_datos: Session,
) -> list[dict]:
    resultados = base_datos.execute(
        select(HistorialParticipacion, Partido)
        .join(
            Partido,
            HistorialParticipacion.partido_id == Partido.id,
        )
        .where(HistorialParticipacion.usuario_id == usuario.id)
        .order_by(
            HistorialParticipacion.fecha_evento.desc(),
            HistorialParticipacion.id.desc(),
        )
    ).all()

    historial = []

    for evento, partido in resultados:
        historial.append(
            {
                "id": evento.id,
                "accion": evento.accion,
                "fecha_evento": evento.fecha_evento,
                "partido_id": partido.id,
                "nombre_partido": partido.nombre,
                "deporte": partido.deporte,
                "ubicacion": partido.ubicacion,
                "fecha_partido": partido.fecha,
                "estado": partido.estado,
            }
        )

    return historial


def listar_partidos_publicos(
    usuario: Usuario,
    base_datos: Session,
    busqueda: str | None = None,
    deporte: str | None = None,
    zona: str | None = None,
    desde: date | None = None,
    hasta: date | None = None,
    solo_con_cupos: bool = False,
) -> list[Partido]:
    consulta = (
        select(Partido)
        .where(Partido.usuario_id != usuario.id)
        # Un partido vencido ya no admite inscripciones: no se ofrece al explorar
        .where(Partido.fecha > datetime.now(timezone.utc))
        .options(
            selectinload(Partido.usuario),
            selectinload(Partido.participantes).selectinload(
                PartidoParticipante.usuario
            ),
        )
    )

    if busqueda and busqueda.strip():
        texto = f"%{busqueda.strip().lower()}%"
        consulta = consulta.where(func.lower(Partido.nombre).like(texto))

    if deporte and deporte.strip():
        consulta = consulta.where(
            func.lower(Partido.deporte) == deporte.strip().lower()
        )

    if zona and zona.strip():
        texto = f"%{zona.strip().lower()}%"
        consulta = consulta.where(func.lower(Partido.ubicacion).like(texto))

    if desde:
        fecha_desde = datetime.combine(desde, time.min, tzinfo=timezone.utc)
        consulta = consulta.where(Partido.fecha >= fecha_desde)

    if hasta:
        fecha_hasta = datetime.combine(
            hasta + timedelta(days=1),
            time.min,
            tzinfo=timezone.utc,
        )
        consulta = consulta.where(Partido.fecha < fecha_hasta)

    if solo_con_cupos:
        cantidad_participantes = (
            select(func.count())
            .select_from(PartidoParticipante)
            .where(
                PartidoParticipante.partido_id == Partido.id,
                PartidoParticipante.es_suplente.is_(False),
            )
            .scalar_subquery()
        )
        usuario_ya_unido = exists().where(
            PartidoParticipante.partido_id == Partido.id,
            PartidoParticipante.usuario_id == usuario.id,
        )

        consulta = consulta.where(
            Partido.estado == "cupos abiertos",
            Partido.fecha.is_not(None),
            Partido.fecha > datetime.now(timezone.utc),
            cantidad_participantes < Partido.cantidad_jugadores,
            ~usuario_ya_unido,
        )

    return list(
        base_datos.scalars(
            consulta.order_by(Partido.fecha, Partido.id)
        ).all()
    )


def actualizar_partido(
    partido: Partido,
    datos: ActualizacionPartido,
    base_datos: Session,
) -> Partido:
    cambios = datos.model_dump(exclude_unset=True)
    if hay_confirmaciones_pendientes(partido) and (
        "fecha" in cambios or "ubicacion" in cambios
    ):
        raise ErrorPartido(
            "REPROGRAMACION_PENDIENTE",
            "Hay titulares que aún no responden la reprogramación",
        )
    if "fecha" in cambios:
        cambios["fecha"] = validar_fecha_futura(cambios["fecha"])
    for nombre in ("nombre", "ubicacion", "tiempo_min"):
        if nombre in cambios and cambios[nombre] is not None:
            cambios[nombre] = cambios[nombre].strip()
    if "cantidad_jugadores" in cambios:
        cantidad_participantes = contar_titulares(partido.id, base_datos)
        if cambios["cantidad_jugadores"] < cantidad_participantes:
            raise ErrorPartido(
                "CAPACIDAD_INSUFICIENTE",
                "La capacidad no puede ser menor que los participantes",
            )
    for nombre, valor in cambios.items():
        setattr(partido, nombre, valor)
    if "cantidad_jugadores" in cambios:
        promover_suplentes(partido, base_datos)

    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def hay_confirmaciones_pendientes(partido: Partido) -> bool:
    return any(item.pendiente_confirmar for item in partido.participantes)


def reprogramar_partido(
    partido: Partido,
    datos: Reprogramacion,
    base_datos: Session,
) -> Partido:
    """Change date or place with a reason; holders must reconfirm."""
    if hay_confirmaciones_pendientes(partido):
        raise ErrorPartido(
            "REPROGRAMACION_PENDIENTE",
            "Hay titulares que aún no responden la reprogramación",
        )

    cambios = {}
    if datos.fecha is not None:
        fecha = validar_fecha_futura(datos.fecha)
        actual = partido.fecha
        if actual is not None and actual.tzinfo is None:
            actual = actual.replace(tzinfo=timezone.utc)
        if fecha != actual:
            cambios["fecha"] = fecha
    if datos.ubicacion is not None:
        ubicacion = datos.ubicacion.strip()
        if ubicacion and ubicacion != partido.ubicacion:
            cambios["ubicacion"] = ubicacion

    motivo = datos.motivo.strip()
    if not motivo:
        raise ErrorPartido("MOTIVO_OBLIGATORIO", "Escribe el motivo del cambio")
    if not cambios:
        raise ErrorPartido(
            "SIN_CAMBIOS",
            "Cambia la fecha o el lugar para reprogramar",
        )

    for nombre, valor in cambios.items():
        setattr(partido, nombre, valor)
    partido.motivo_reprogramacion = motivo
    # Holders keep their spot while they answer; substitutes are not asked.
    for item in partido.participantes:
        if not item.es_suplente:
            item.pendiente_confirmar = True

    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def reconfirmar_partido(
    partido_id: int,
    usuario: Usuario,
    base_datos: Session,
) -> Partido | None:
    partido = buscar_partido_publico(partido_id, base_datos)
    if not partido:
        return None

    participante = base_datos.scalar(
        select(PartidoParticipante).where(
            PartidoParticipante.partido_id == partido_id,
            PartidoParticipante.usuario_id == usuario.id,
        )
    )
    if not participante:
        raise ErrorPartido("NO_INSCRITO", "No estás unido a este partido")
    if not participante.pendiente_confirmar:
        raise ErrorPartido(
            "SIN_RECONFIRMACION",
            "No tienes una reprogramación por confirmar",
        )

    participante.pendiente_confirmar = False
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def eliminar_partido(partido: Partido, base_datos: Session) -> None:
    base_datos.delete(partido)
    base_datos.commit()



def completar_equipo(partido: Partido, base_datos: Session) -> Partido:
    if partido.estado != "cupos abiertos":
        raise ErrorPartido(
            "EQUIPO_COMPLETO",
            "El equipo ya está completo",
        )
    partido.estado = "equipo completo"
    base_datos.commit()
    base_datos.refresh(partido)

    return partido


def reabrir_equipo(partido: Partido, base_datos: Session) -> Partido:
    if partido.estado != "equipo completo":
        raise ErrorPartido(
            "EQUIPO_ABIERTO",
            "El equipo ya tiene los cupos abiertos",
        )
    partido.estado = "cupos abiertos"
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def contar_titulares(partido_id: int, base_datos: Session) -> int:
    return base_datos.scalar(
        select(func.count())
        .select_from(PartidoParticipante)
        .where(
            PartidoParticipante.partido_id == partido_id,
            PartidoParticipante.es_suplente.is_(False),
        )
    )


def promover_suplentes(partido: Partido, base_datos: Session) -> int:
    """Move substitutes, first come first served, into free holder spots."""
    base_datos.flush()
    promovidos = 0
    while contar_titulares(partido.id, base_datos) < partido.cantidad_jugadores:
        siguiente = base_datos.scalar(
            select(PartidoParticipante)
            .where(
                PartidoParticipante.partido_id == partido.id,
                PartidoParticipante.es_suplente.is_(True),
            )
            .order_by(PartidoParticipante.unido_en, PartidoParticipante.usuario_id)
            .limit(1)
        )
        if siguiente is None:
            break
        siguiente.es_suplente = False
        base_datos.add(
            HistorialParticipacion(
                usuario_id=siguiente.usuario_id,
                partido_id=partido.id,
                accion="paso_a_titular",
            )
        )
        base_datos.flush()
        promovidos += 1
    if promovidos and contar_titulares(partido.id, base_datos) >= (
        partido.cantidad_jugadores
    ):
        partido.estado = "equipo completo"
    return promovidos


def unirse_partido(
    partido_id: int,
    usuario: Usuario,
    base_datos: Session,
) -> Partido | None:
    partido = buscar_partido_publico(partido_id, base_datos)
    if not partido:
        return None

    if partido.usuario_id == usuario.id:
        raise ErrorPartido(
            "ORGANIZADOR_NO_PUEDE_UNIRSE",
            "El organizador no puede unirse a su propio partido",
        )

    if partido.fecha is None:
        raise ErrorPartido(
            "FECHA_NO_DISPONIBLE",
            "El partido debe tener una fecha futura",
        )

    fecha = partido.fecha
    if fecha.tzinfo is None:
        fecha = fecha.replace(tzinfo=timezone.utc)
    if fecha <= datetime.now(timezone.utc):
        raise ErrorPartido(
            "FECHA_PASADA",
            "La fecha del partido ya pasó",
        )

    participante = base_datos.scalar(
        select(PartidoParticipante).where(
            PartidoParticipante.partido_id == partido_id,
            PartidoParticipante.usuario_id == usuario.id,
        )
    )
    if participante:
        raise ErrorPartido(
            "YA_INSCRITO",
            "Ya estás unido a este partido",
        )

    titulares = contar_titulares(partido_id, base_datos)
    hay_cupo = titulares < partido.cantidad_jugadores
    if hay_cupo and partido.estado != "cupos abiertos":
        # The organizer closed the team while there were still free spots.
        raise ErrorPartido(
            "EQUIPO_COMPLETO",
            "El equipo ya está completo",
        )

    # With the holders' spots taken, the newcomer waits as a substitute.
    es_suplente = not hay_cupo
    base_datos.add(
        PartidoParticipante(
            partido_id=partido_id,
            usuario_id=usuario.id,
            es_suplente=es_suplente,
        )
    )

    base_datos.add(
        HistorialParticipacion(
            usuario_id=usuario.id,
            partido_id=partido.id,
            accion="se_unio_suplente" if es_suplente else "se_unio",
        )
    )

    if not es_suplente and titulares + 1 >= partido.cantidad_jugadores:
        partido.estado = "equipo completo"

    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def es_baja_tardia(partido: Partido) -> bool:
    fecha = partido.fecha
    if fecha is None:
        return False
    if fecha.tzinfo is None:
        fecha = fecha.replace(tzinfo=timezone.utc)
    return fecha - datetime.now(timezone.utc) < PLAZO_BAJA


def salir_partido(
    partido_id: int,
    usuario: Usuario,
    base_datos: Session,
) -> Partido | None:
    partido = buscar_partido_publico(partido_id, base_datos)
    if not partido:
        return None

    if partido.usuario_id == usuario.id:
        raise ErrorPartido(
            "ORGANIZADOR_NO_PUEDE_SALIR",
            "El organizador no puede salir de su propio partido",
        )

    participante = base_datos.scalar(
        select(PartidoParticipante).where(
            PartidoParticipante.partido_id == partido_id,
            PartidoParticipante.usuario_id == usuario.id,
        )
    )
    if not participante:
        raise ErrorPartido(
            "NO_INSCRITO",
            "No estás unido a este partido",
        )

    # Leaving must not break the result validation: the rival captain has
    # to stay to validate the score, and accepted teams cannot shrink.
    fecha = partido.fecha
    if fecha is not None:
        if fecha.tzinfo is None:
            fecha = fecha.replace(tzinfo=timezone.utc)
        if fecha <= datetime.now(timezone.utc):
            raise ErrorPartido(
                "PARTIDO_YA_JUGADO",
                "No puedes salir de un partido que ya se jugó",
            )
    if partido.capitan_rival_id == usuario.id:
        raise ErrorPartido(
            "CAPITAN_NO_PUEDE_SALIR",
            "Eres el capitán rival: pide al organizador que elija otro "
            "capitán antes de salir",
        )
    if partido.equipos_aceptados and participante.equipo is not None:
        raise ErrorPartido(
            "EQUIPOS_ACEPTADOS",
            "Los equipos ya fueron aceptados: pide al organizador que los "
            "cambie antes de salir",
        )

    tardia = es_baja_tardia(partido)
    era_suplente = participante.es_suplente
    base_datos.delete(participante)
    if tardia:
        base_datos.add(
            HistorialParticipacion(
                usuario_id=usuario.id,
                partido_id=partido.id,
                accion="baja_tardia",
            )
        )
    if not era_suplente:
        # The first substitute takes the freed spot; with none waiting, the
        # spot opens up again.
        promovidos = promover_suplentes(partido, base_datos)
        if not promovidos and partido.estado == "equipo completo":
            partido.estado = "cupos abiertos"
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def bajas_tardias(partido: Partido) -> list[Usuario]:
    sesion = object_session(partido)
    if sesion is None:
        return []
    return list(
        sesion.scalars(
            select(Usuario)
            .join(
                HistorialParticipacion,
                HistorialParticipacion.usuario_id == Usuario.id,
            )
            .where(
                HistorialParticipacion.partido_id == partido.id,
                HistorialParticipacion.accion == "baja_tardia",
            )
            .order_by(HistorialParticipacion.fecha_evento, HistorialParticipacion.id)
        ).all()
    )


def datos_partido(partido: Partido) -> dict:
    ordenados = sorted(
        partido.participantes,
        key=lambda item: (item.unido_en, item.usuario_id),
    )
    participantes = [item.usuario for item in ordenados if not item.es_suplente]
    suplentes = [item.usuario for item in ordenados if item.es_suplente]
    pendientes = [
        item.usuario
        for item in ordenados
        if item.pendiente_confirmar and not item.es_suplente
    ]
    cantidad_participantes = len(participantes)
    estado = partido.estado.strip().lower()
    return {
        "id": partido.id,
        "nombre": partido.nombre,
        "cantidad_jugadores": partido.cantidad_jugadores,
        "ubicacion": partido.ubicacion,
        "tiempo_min": partido.tiempo_min,
        "fecha": partido.fecha,
        "estado": estado,
        "participantes": participantes,
        "cantidad_participantes": cantidad_participantes,
        "suplentes": suplentes,
        "cantidad_suplentes": len(suplentes),
        "motivo_reprogramacion": partido.motivo_reprogramacion,
        "pendientes_confirmar": pendientes,
        "bajas_tardias": bajas_tardias(partido),
        "cupos_disponibles": max(
            partido.cantidad_jugadores - cantidad_participantes,
            0,
        ),

        "deporte": partido.deporte,
    }


def datos_partido_publico(partido: Partido) -> dict:
    datos = datos_partido(partido)
    datos["organizador"] = partido.usuario
    return datos
