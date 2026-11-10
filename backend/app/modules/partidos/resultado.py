"""Result validation between people.

The organizer proposes two teams and a rival captain (team B), who accepts
them before the match. After the match the organizer registers the score and
the captain confirms it or disputes it with a reason. A correction is a new
score version that needs a new validation. Every version is kept; only the
confirmed one is definitive.
"""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.database.models import (
    Partido,
    PartidoParticipante,
    ResultadoPartido,
    Usuario,
)
from app.modules.partidos.service import ErrorPartido, buscar_partido_publico


def _ahora() -> datetime:
    return datetime.now(timezone.utc)


def partido_jugado(partido: Partido) -> bool:
    if partido.fecha is None:
        return False
    fecha = partido.fecha
    if fecha.tzinfo is None:
        fecha = fecha.replace(tzinfo=timezone.utc)
    return fecha <= _ahora()


def _titulares(partido: Partido) -> list[PartidoParticipante]:
    return sorted(
        (item for item in partido.participantes if not item.es_suplente),
        key=lambda item: (item.unido_en, item.usuario_id),
    )


def _ultimo_resultado(partido: Partido) -> ResultadoPartido | None:
    return max(partido.resultados, key=lambda r: r.version, default=None)


def _resultado_confirmado(partido: Partido) -> ResultadoPartido | None:
    return next((r for r in partido.resultados if r.estado == "confirmado"), None)


def estado_validacion(partido: Partido) -> str:
    ultimo = _ultimo_resultado(partido)
    if ultimo is not None:
        return f"resultado_{ultimo.estado}"
    if partido.capitan_rival_id is None:
        return "sin_equipos"
    return "equipos_aceptados" if partido.equipos_aceptados else "equipos_propuestos"


def _buscar(partido_id: int, base_datos: Session) -> Partido | None:
    partido = buscar_partido_publico(partido_id, base_datos)
    if partido is not None:
        base_datos.refresh(partido, ["resultados"])
    return partido


def _exigir_capitan(partido: Partido, usuario: Usuario) -> None:
    if partido.capitan_rival_id != usuario.id:
        raise ErrorPartido(
            "SOLO_CAPITAN",
            "Solo el capitán rival puede hacer esto",
        )


def proponer_equipos(
    partido: Partido,
    equipo_b_ids: list[int],
    capitan_id: int,
    base_datos: Session,
) -> Partido:
    """Holders listed in equipo_b_ids form team B; the rest form team A."""
    if partido.resultados:
        raise ErrorPartido(
            "EQUIPOS_BLOQUEADOS",
            "Los equipos no se pueden cambiar después de registrar el marcador",
        )
    if partido_jugado(partido):
        raise ErrorPartido("PARTIDO_YA_JUGADO", "El partido ya se jugó")

    titulares = _titulares(partido)
    ids_titulares = {item.usuario_id for item in titulares}
    equipo_b = set(equipo_b_ids)
    if not equipo_b or not equipo_b <= ids_titulares:
        raise ErrorPartido(
            "EQUIPOS_INVALIDOS",
            "El equipo rival debe tener al menos un jugador inscrito",
        )
    if capitan_id not in equipo_b:
        raise ErrorPartido(
            "EQUIPOS_INVALIDOS",
            "El capitán rival debe ser parte del equipo rival",
        )

    for item in titulares:
        item.equipo = "B" if item.usuario_id in equipo_b else "A"
    partido.capitan_rival_id = capitan_id
    # A new proposal, even a change, needs the captain's acceptance again.
    partido.equipos_aceptados = False
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def aceptar_equipos(partido_id: int, usuario: Usuario, base_datos: Session) -> Partido | None:
    partido = _buscar(partido_id, base_datos)
    if partido is None:
        return None
    if partido.capitan_rival_id is None:
        raise ErrorPartido("EQUIPOS_NO_PROPUESTOS", "Todavía no hay equipos propuestos")
    _exigir_capitan(partido, usuario)
    if partido_jugado(partido):
        raise ErrorPartido(
            "PARTIDO_YA_JUGADO",
            "Los equipos se aceptan antes del partido",
        )
    if partido.equipos_aceptados:
        raise ErrorPartido("EQUIPOS_YA_ACEPTADOS", "Ya aceptaste estos equipos")
    partido.equipos_aceptados = True
    base_datos.commit()
    base_datos.refresh(partido)
    return partido


def registrar_resultado(
    partido: Partido,
    goles_a: int,
    goles_b: int,
    base_datos: Session,
) -> Partido:
    """Register the score, or a correction after a dispute."""
    base_datos.refresh(partido, ["resultados"])
    if goles_a < 0 or goles_b < 0:
        raise ErrorPartido("MARCADOR_INVALIDO", "El marcador no puede ser negativo")
    if _resultado_confirmado(partido) is not None:
        raise ErrorPartido(
            "RESULTADO_CONFIRMADO",
            "El resultado ya fue confirmado y es definitivo",
        )
    ultimo = _ultimo_resultado(partido)
    if ultimo is not None and ultimo.estado == "pendiente":
        raise ErrorPartido(
            "RESULTADO_PENDIENTE",
            "El marcador anterior todavía espera la validación del capitán",
        )
    if not partido.equipos_aceptados:
        raise ErrorPartido(
            "EQUIPOS_SIN_ACEPTAR",
            "El capitán rival todavía no aceptó los equipos",
        )
    if not partido_jugado(partido):
        raise ErrorPartido(
            "PARTIDO_NO_TERMINADO",
            "El marcador se registra cuando termina el partido",
        )

    base_datos.add(
        ResultadoPartido(
            partido_id=partido.id,
            version=(ultimo.version + 1) if ultimo else 1,
            goles_a=goles_a,
            goles_b=goles_b,
            estado="pendiente",
        )
    )
    base_datos.commit()
    base_datos.refresh(partido, ["resultados"])
    return partido


def _resultado_pendiente(partido: Partido, usuario: Usuario) -> ResultadoPartido:
    _exigir_capitan(partido, usuario)
    ultimo = _ultimo_resultado(partido)
    if ultimo is None or ultimo.estado != "pendiente":
        raise ErrorPartido(
            "SIN_RESULTADO_PENDIENTE",
            "No hay un marcador esperando validación",
        )
    return ultimo


def confirmar_resultado(partido_id: int, usuario: Usuario, base_datos: Session) -> Partido | None:
    partido = _buscar(partido_id, base_datos)
    if partido is None:
        return None
    resultado = _resultado_pendiente(partido, usuario)
    resultado.estado = "confirmado"
    resultado.respondido_en = _ahora()
    base_datos.commit()
    base_datos.refresh(partido, ["resultados"])
    return partido


def disputar_resultado(
    partido_id: int,
    usuario: Usuario,
    motivo: str,
    base_datos: Session,
) -> Partido | None:
    partido = _buscar(partido_id, base_datos)
    if partido is None:
        return None
    resultado = _resultado_pendiente(partido, usuario)
    motivo = motivo.strip()
    if not motivo:
        raise ErrorPartido("MOTIVO_OBLIGATORIO", "Escribe el motivo de la disputa")
    resultado.estado = "disputado"
    resultado.motivo_disputa = motivo
    resultado.respondido_en = _ahora()
    base_datos.commit()
    base_datos.refresh(partido, ["resultados"])
    return partido


def puede_ver(partido: Partido, usuario: Usuario) -> bool:
    return partido.usuario_id == usuario.id or any(
        item.usuario_id == usuario.id for item in partido.participantes
    )


def datos_validacion(partido: Partido, usuario: Usuario) -> dict:
    titulares = _titulares(partido)
    confirmado = _resultado_confirmado(partido)
    return {
        "partido_id": partido.id,
        "nombre": partido.nombre,
        "fecha": partido.fecha,
        "ubicacion": partido.ubicacion,
        "organizador": partido.usuario,
        "titulares": [item.usuario for item in titulares],
        "equipo_a": [item.usuario for item in titulares if item.equipo == "A"],
        "equipo_b": [item.usuario for item in titulares if item.equipo == "B"],
        "capitan_rival": partido.capitan_rival,
        "equipos_aceptados": partido.equipos_aceptados,
        "partido_jugado": partido_jugado(partido),
        "estado_validacion": estado_validacion(partido),
        "es_organizador": partido.usuario_id == usuario.id,
        "es_capitan": partido.capitan_rival_id == usuario.id,
        "resultado_definitivo": (
            {"goles_a": confirmado.goles_a, "goles_b": confirmado.goles_b}
            if confirmado
            else None
        ),
        "resultados": [
            {
                "version": r.version,
                "goles_a": r.goles_a,
                "goles_b": r.goles_b,
                "estado": r.estado,
                "motivo_disputa": r.motivo_disputa,
                "registrado_en": r.registrado_en,
                "respondido_en": r.respondido_en,
            }
            for r in sorted(partido.resultados, key=lambda r: r.version, reverse=True)
        ],
    }


def listar_partidos_participando(usuario: Usuario, base_datos: Session) -> list[Partido]:
    """Matches the user joined, played ones included (Explorar hides those)."""
    return list(
        base_datos.scalars(
            select(Partido)
            .join(PartidoParticipante, PartidoParticipante.partido_id == Partido.id)
            .where(PartidoParticipante.usuario_id == usuario.id)
            .order_by(Partido.fecha.desc(), Partido.id)
            .options(
                selectinload(Partido.usuario),
                selectinload(Partido.participantes).selectinload(
                    PartidoParticipante.usuario
                ),
            )
        ).all()
    )
