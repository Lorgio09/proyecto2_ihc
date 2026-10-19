"""juan. Aqui estan los servicios para hacer un crud, crea, actualiza, edita y elimina los partidoss"""
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import exists, func, select
from sqlalchemy.orm import Session, selectinload

from app.database.models import HistorialParticipacion, Partido, PartidoParticipante, Usuario
from app.modules.partidos.schemas import ActualizacionPartido, DatosPartido


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
            .where(PartidoParticipante.partido_id == Partido.id)
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
    if "fecha" in cambios:
        cambios["fecha"] = validar_fecha_futura(cambios["fecha"])
    for nombre in ("nombre", "ubicacion", "tiempo_min"):
        if nombre in cambios and cambios[nombre] is not None:
            cambios[nombre] = cambios[nombre].strip()
    if "cantidad_jugadores" in cambios:
        cantidad_participantes = base_datos.scalar(
            select(func.count())
            .select_from(PartidoParticipante)
            .where(PartidoParticipante.partido_id == partido.id)
        )
        if cambios["cantidad_jugadores"] < cantidad_participantes:
            raise ErrorPartido(
                "CAPACIDAD_INSUFICIENTE",
                "La capacidad no puede ser menor que los participantes",
            )
    for nombre, valor in cambios.items():
        setattr(partido, nombre, valor)

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

    if partido.estado != "cupos abiertos":
        raise ErrorPartido(
            "EQUIPO_COMPLETO",
            "El equipo ya está completo",
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

    cantidad_participantes = base_datos.scalar(
        select(func.count())
        .select_from(PartidoParticipante)
        .where(PartidoParticipante.partido_id == partido_id)
    )
    if cantidad_participantes >= partido.cantidad_jugadores:
        raise ErrorPartido(
            "SIN_CUPOS",
            "No quedan cupos disponibles",
        )

    base_datos.add(
        PartidoParticipante(
            partido_id=partido_id,
            usuario_id=usuario.id,
        )
    )

    base_datos.add(
        HistorialParticipacion(
            usuario_id=usuario.id,
            partido_id=partido.id,
            accion="se_unio",
        )
    )

    if cantidad_participantes + 1 >= partido.cantidad_jugadores:
        partido.estado = "equipo completo"

    base_datos.commit()
    base_datos.refresh(partido)
    return partido


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

    base_datos.delete(participante)
    if partido.estado == "equipo completo":
        partido.estado = "cupos abiertos"
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def datos_partido(partido: Partido) -> dict:
    participantes = [item.usuario for item in partido.participantes]
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
