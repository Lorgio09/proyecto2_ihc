"""The account's own data: what UniSport keeps about a person, to see it and
take it away. Only that person's data: never other players' names or emails,
and never the password hash or recovery tokens."""
import secrets
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.models import HistorialParticipacion, Partido, PartidoParticipante, Usuario


def _fecha(valor: datetime | None) -> str | None:
    return valor.isoformat() if valor is not None else None


def mis_datos(usuario: Usuario, base_datos: Session) -> dict:
    organizados = base_datos.scalars(
        select(Partido)
        .where(Partido.usuario_id == usuario.id)
        .order_by(Partido.fecha, Partido.id)
    ).all()
    participaciones = base_datos.scalars(
        select(PartidoParticipante)
        .where(PartidoParticipante.usuario_id == usuario.id)
        .order_by(PartidoParticipante.unido_en)
    ).all()
    historial = base_datos.scalars(
        select(HistorialParticipacion)
        .where(HistorialParticipacion.usuario_id == usuario.id)
        .order_by(HistorialParticipacion.fecha_evento, HistorialParticipacion.id)
    ).all()
    nombres = {
        partido.id: partido.nombre
        for partido in base_datos.scalars(
            select(Partido).where(
                Partido.id.in_({item.partido_id for item in historial})
            )
        )
    }

    return {
        "generado_en": datetime.now(timezone.utc).isoformat(),
        "cuenta": {
            "nombre": usuario.nombre,
            "email": usuario.email,
            "telefono": usuario.telefono,
        },
        "partidos_organizados": [
            {
                "nombre": partido.nombre,
                "deporte": partido.deporte,
                "fecha": _fecha(partido.fecha),
                "ubicacion": partido.ubicacion,
                "cantidad_jugadores": partido.cantidad_jugadores,
                "estado": partido.estado,
            }
            for partido in organizados
        ],
        "participaciones": [
            {
                "partido": item.partido.nombre,
                "fecha": _fecha(item.partido.fecha),
                "ubicacion": item.partido.ubicacion,
                "rol": "suplente" if item.es_suplente else "titular",
                "equipo": item.equipo,
                "unido_en": _fecha(item.unido_en),
            }
            for item in participaciones
        ],
        "historial": [
            {
                "accion": item.accion,
                "fecha": _fecha(item.fecha_evento),
                "partido": nombres.get(item.partido_id),
            }
            for item in historial
        ],
    }


# --- Deleting the account ---------------------------------------------------

ANONIMO_EMAIL = "usuario-eliminado@unisport.invalid"
ANONIMO_NOMBRE = "Usuario eliminado"


class ErrorCuenta(ValueError):
    def __init__(self, codigo: str, mensaje: str, bloqueos: list[dict]):
        self.codigo = codigo
        self.mensaje = mensaje
        self.bloqueos = bloqueos
        super().__init__(mensaje)


def _aun_no_se_juega(partido: Partido) -> bool:
    fecha = partido.fecha
    if fecha is None:
        return True
    if fecha.tzinfo is None:
        fecha = fecha.replace(tzinfo=timezone.utc)
    return fecha > datetime.now(timezone.utc)


def _tiene_resultado_confirmado(partido: Partido) -> bool:
    return any(resultado.estado == "confirmado" for resultado in partido.resultados)


def _organizados(usuario: Usuario, base_datos: Session) -> list[Partido]:
    return list(
        base_datos.scalars(select(Partido).where(Partido.usuario_id == usuario.id))
    )


def bloqueos_eliminacion(usuario: Usuario, base_datos: Session) -> list[dict]:
    """What stops the deletion, each one saying why and what to do."""
    bloqueos = []

    con_jugadores = [
        partido.nombre
        for partido in _organizados(usuario, base_datos)
        if _aun_no_se_juega(partido) and partido.participantes
    ]
    if con_jugadores:
        bloqueos.append(
            {
                "codigo": "ORGANIZA_PARTIDOS_CON_JUGADORES",
                "mensaje": (
                    "Organizas partidos que todavía no se jugaron y ya tienen "
                    f"jugadores: {', '.join(con_jugadores)}. Si borráramos tu "
                    "cuenta, ellos se quedarían sin partido y sin aviso. "
                    "Elimínalos desde Mis partidos (menú Más acciones, "
                    "Eliminar partido) y vuelve a intentarlo."
                ),
            }
        )

    por_validar = [
        partido.nombre
        for partido in base_datos.scalars(
            select(Partido).where(Partido.capitan_rival_id == usuario.id)
        )
        if partido.resultados and partido.resultados[-1].estado == "pendiente"
    ]
    if por_validar:
        bloqueos.append(
            {
                "codigo": "CAPITAN_CON_RESULTADO_PENDIENTE",
                "mensaje": (
                    f"Eres capitán rival en {', '.join(por_validar)} y hay un "
                    "marcador esperando tu validación. Sin ti nadie podría "
                    "validarlo. Confírmalo o dispútalo en Mis partidos, "
                    "pestaña Me uní, Resultado, y vuelve a intentarlo."
                ),
            }
        )
    return bloqueos


def consecuencias_eliminacion(usuario: Usuario, base_datos: Session) -> dict:
    """What will happen, in numbers, so the confirmation can say it plainly."""
    futuras = [
        item for item in usuario.partidos_participados if _aun_no_se_juega(item.partido)
    ]
    ascensos = sum(
        1
        for item in futuras
        if not item.es_suplente
        and any(otro.es_suplente for otro in item.partido.participantes)
    )
    organizados = _organizados(usuario, base_datos)
    con_resultado = {
        item.partido.id
        for item in usuario.partidos_participados
        if _tiene_resultado_confirmado(item.partido)
    } | {partido.id for partido in organizados if _tiene_resultado_confirmado(partido)}
    return {
        "partidos_futuros": len(futuras),
        "ascensos_de_suplentes": ascensos,
        "partidos_organizados_eliminados": sum(
            1 for partido in organizados if not _tiene_resultado_confirmado(partido)
        ),
        "resultados_anonimizados": len(con_resultado),
    }


def _usuario_anonimo(base_datos: Session) -> Usuario:
    anonimo = base_datos.scalar(select(Usuario).where(Usuario.email == ANONIMO_EMAIL))
    if anonimo is None:
        from app.modules.auth.service import hash_password

        # A random password nobody knows: this account can never sign in.
        anonimo = Usuario(
            nombre=ANONIMO_NOMBRE,
            email=ANONIMO_EMAIL,
            password_hash=hash_password(secrets.token_urlsafe(32)),
        )
        base_datos.add(anonimo)
        base_datos.flush()
    return anonimo


def eliminar_cuenta(usuario: Usuario, base_datos: Session) -> None:
    """Delete the account with UniSport's rule: a holder's spot in a future
    match goes to the first substitute, and confirmed results stay, with the
    person replaced by an anonymous "Usuario eliminado"."""
    from app.modules.partidos.service import promover_suplentes

    bloqueos = bloqueos_eliminacion(usuario, base_datos)
    if bloqueos:
        raise ErrorCuenta(bloqueos[0]["codigo"], bloqueos[0]["mensaje"], bloqueos)

    anonimo = None

    for item in list(usuario.partidos_participados):
        partido = item.partido
        if _aun_no_se_juega(partido):
            era_titular = not item.es_suplente
            base_datos.delete(item)
            base_datos.flush()
            base_datos.refresh(partido)
            if era_titular:
                promovidos = promover_suplentes(partido, base_datos)
                if not promovidos and partido.estado == "equipo completo":
                    partido.estado = "cupos abiertos"
        elif _tiene_resultado_confirmado(partido):
            anonimo = anonimo or _usuario_anonimo(base_datos)
            if any(otro.usuario_id == anonimo.id for otro in partido.participantes):
                base_datos.delete(item)
            else:
                item.usuario_id = anonimo.id
        else:
            base_datos.delete(item)

    for partido in base_datos.scalars(
        select(Partido).where(Partido.capitan_rival_id == usuario.id)
    ):
        if _tiene_resultado_confirmado(partido):
            anonimo = anonimo or _usuario_anonimo(base_datos)
            partido.capitan_rival_id = anonimo.id
        else:
            # The teams need a new captain, who has to accept them again.
            partido.capitan_rival_id = None
            partido.equipos_aceptados = False

    for partido in _organizados(usuario, base_datos):
        if _tiene_resultado_confirmado(partido):
            anonimo = anonimo or _usuario_anonimo(base_datos)
            partido.usuario_id = anonimo.id
        else:
            base_datos.delete(partido)

    # The history and the recovery token go with the account.
    for registro in base_datos.scalars(
        select(HistorialParticipacion).where(
            HistorialParticipacion.usuario_id == usuario.id
        )
    ):
        base_datos.delete(registro)
    base_datos.flush()
    base_datos.expire(usuario)
    base_datos.delete(usuario)
    base_datos.commit()
