"""Interaction analytics: one function, track(), records what happened.

Only the action is recorded, never the person: no user id, email or free text.
Each event is saved in the `eventos` table and, when GA_MEASUREMENT_ID and
GA_API_SECRET are set, also sent to Google Analytics 4.

The event plan (event, flow, file:line and question) lives in
evidencias/tarea-9.md.
"""
import json
import logging
import threading
import urllib.request
from collections import Counter

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.database.models import Evento

UNION_INICIADA = "union_iniciada"
PARTIDO_UNIDO = "partido_unido"
PARTIDO_CREACION_INICIADA = "partido_creacion_iniciada"
PARTIDO_CREADO = "partido_creado"
REPROGRAMACION_INICIADA = "reprogramacion_iniciada"
PARTIDO_REPROGRAMADO = "partido_reprogramado"
RESULTADO_REGISTRADO = "resultado_registrado"
RESULTADO_DISPUTADO = "resultado_disputado"
RESULTADO_CONFIRMADO = "resultado_confirmado"
BAJA_INICIADA = "baja_iniciada"
BAJA_REGISTRADA = "baja_registrada"
TAREA_FALLIDA = "tarea_fallida"
BUSQUEDA_SIN_RESULTADOS = "busqueda_sin_resultados"

# One funnel per main flow: start -> (intermediate steps) -> success.
EMBUDOS = {
    "crear_partido": [PARTIDO_CREACION_INICIADA, PARTIDO_CREADO],
    "unirse": [UNION_INICIADA, PARTIDO_UNIDO],
    "reprogramar": [REPROGRAMACION_INICIADA, PARTIDO_REPROGRAMADO],
    "validar_resultado": [RESULTADO_REGISTRADO, RESULTADO_CONFIRMADO],
    "darse_de_baja": [BAJA_INICIADA, BAJA_REGISTRADA],
}

# Fixed list of reasons a task can fail: the API error codes plus the checks
# the app makes before calling it. Anything else is stored as OTRO.
MOTIVOS = {
    # Validation
    "CAMPOS_INCOMPLETOS", "FECHA_OBLIGATORIA", "FECHA_NO_FUTURA", "FECHA_PASADA",
    "FECHA_NO_DISPONIBLE", "MOTIVO_OBLIGATORIO", "SIN_CAMBIOS", "MARCADOR_INVALIDO",
    "EQUIPOS_INVALIDOS", "CAPACIDAD_INSUFICIENTE",
    # State of the match
    "EQUIPO_COMPLETO", "EQUIPO_ABIERTO", "YA_INSCRITO", "NO_INSCRITO",
    "PARTIDO_YA_JUGADO", "PARTIDO_NO_TERMINADO", "REPROGRAMACION_PENDIENTE",
    "SIN_RECONFIRMACION", "EQUIPOS_ACEPTADOS", "EQUIPOS_BLOQUEADOS",
    "EQUIPOS_NO_PROPUESTOS", "EQUIPOS_SIN_ACEPTAR", "EQUIPOS_YA_ACEPTADOS",
    "RESULTADO_PENDIENTE", "RESULTADO_CONFIRMADO", "SIN_RESULTADO_PENDIENTE",
    # Permission denied
    "SOLO_ORGANIZADOR", "SOLO_CAPITAN", "ORGANIZADOR_NO_PUEDE_UNIRSE",
    "ORGANIZADOR_NO_PUEDE_SALIR", "CAPITAN_NO_PUEDE_SALIR",
}

# Only start events and the app's own validation failures come from the app;
# every success is recorded by the backend once it was saved.
EVENTOS_DESDE_LA_APP = {
    UNION_INICIADA,
    PARTIDO_CREACION_INICIADA,
    REPROGRAMACION_INICIADA,
    BAJA_INICIADA,
    TAREA_FALLIDA,
}
PROPS_PERMITIDAS = {"deporte", "como_suplente", "tardia", "flujo", "motivo", "filtros"}

GA_URL = "https://www.google-analytics.com/mp/collect"

log = logging.getLogger(__name__)


def enviar_a_ga(evento: str, props: dict) -> None:
    """Send the event to GA4 without blocking the request; failures are logged."""
    if not settings.ga_measurement_id or not settings.ga_api_secret:
        return

    # GA parameters must be text or numbers.
    params = {
        clave: str(valor).lower() if isinstance(valor, bool) else valor
        for clave, valor in props.items()
    }
    params["engagement_time_msec"] = 100
    cuerpo = json.dumps(
        {"client_id": "unisport-backend", "events": [{"name": evento, "params": params}]}
    ).encode()
    url = (
        f"{GA_URL}?measurement_id={settings.ga_measurement_id}"
        f"&api_secret={settings.ga_api_secret}"
    )

    def enviar():
        try:
            peticion = urllib.request.Request(
                url, data=cuerpo, headers={"Content-Type": "application/json"}
            )
            urllib.request.urlopen(peticion, timeout=5).close()
        except Exception as error:  # GA must never break the app
            log.warning("No se pudo enviar %s a Google Analytics: %s", evento, error)

    threading.Thread(target=enviar, daemon=True).start()


def limpiar_props(evento: str, props: dict | None) -> dict:
    props = {
        clave: valor
        for clave, valor in (props or {}).items()
        if clave in PROPS_PERMITIDAS
    }
    if evento == TAREA_FALLIDA:
        if props.get("flujo") not in EMBUDOS:
            props["flujo"] = "otro"
        if props.get("motivo") not in MOTIVOS:
            props["motivo"] = "OTRO"
    return props


def track(base_datos: Session, evento: str, props: dict | None = None) -> Evento:
    props = limpiar_props(evento, props)
    registro = Evento(evento=evento, props=props)
    base_datos.add(registro)
    base_datos.commit()
    base_datos.refresh(registro)
    enviar_a_ga(evento, props)
    return registro


def registrar(base_datos: Session, evento: str, props: dict | None = None) -> None:
    """track() for request handlers: an analytics failure never breaks them."""
    try:
        track(base_datos, evento, props)
    except Exception as error:
        log.warning("No se pudo registrar %s: %s", evento, error)


def registrar_fallo(base_datos: Session, flujo: str, motivo: str) -> None:
    """Record a task that failed. Discards the request's unsaved changes first
    and never raises: analytics must not hide the real error."""
    try:
        base_datos.rollback()
        track(base_datos, TAREA_FALLIDA, {"flujo": flujo, "motivo": motivo})
    except Exception as error:
        log.warning("No se pudo registrar el fallo de %s: %s", flujo, error)


def resumen(base_datos: Session) -> dict:
    conteos = dict(
        base_datos.execute(
            select(Evento.evento, func.count()).group_by(Evento.evento)
        ).all()
    )

    embudos = []
    for flujo, pasos in EMBUDOS.items():
        filas = []
        anterior = None
        for evento in pasos:
            cantidad = conteos.get(evento, 0)
            # A success can arrive without its start (the app sends starts in
            # the background), so a step never shows a negative drop.
            caida = (
                max(round((anterior - cantidad) * 100 / anterior), 0)
                if anterior
                else None
            )
            filas.append({"evento": evento, "cantidad": cantidad, "caida": caida})
            anterior = cantidad
        inicio = filas[0]["cantidad"]
        embudos.append(
            {
                "flujo": flujo,
                "pasos": filas,
                "termina": (
                    min(round(filas[-1]["cantidad"] * 100 / inicio), 100) if inicio else 0
                ),
            }
        )

    con_caida = [
        (paso["caida"], embudo["flujo"], paso["evento"])
        for embudo in embudos
        for paso in embudo["pasos"]
        if paso["caida"] is not None
    ]
    mayor = max(con_caida, default=None)

    fallos = Counter(
        (item.props.get("flujo", "otro"), item.props.get("motivo", "OTRO"))
        for item in base_datos.scalars(
            select(Evento).where(Evento.evento == TAREA_FALLIDA)
        )
    )
    ultimos = base_datos.scalars(
        select(Evento).order_by(Evento.fecha.desc(), Evento.id.desc()).limit(15)
    ).all()
    return {
        "conteos": conteos,
        "embudos": embudos,
        "mayor_caida": (
            {"flujo": mayor[1], "evento": mayor[2], "caida": mayor[0]} if mayor else None
        ),
        "errores": [
            {"flujo": flujo, "motivo": motivo, "cantidad": cantidad}
            for (flujo, motivo), cantidad in fallos.most_common()
        ],
        "busquedas_sin_resultados": conteos.get(BUSQUEDA_SIN_RESULTADOS, 0),
        "ultimos": [
            {"evento": item.evento, "props": item.props, "fecha": item.fecha}
            for item in ultimos
        ],
    }
