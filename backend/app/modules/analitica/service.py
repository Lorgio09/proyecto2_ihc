"""Interaction analytics: one function, track(), records what happened.

Only the action is recorded, never the person: no user id, email or free text.
Each event is saved in the `eventos` table and, when GA_MEASUREMENT_ID and
GA_API_SECRET are set, also sent to Google Analytics 4.
"""
import json
import logging
import threading
import urllib.request

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.database.models import Evento

UNION_INICIADA = "union_iniciada"
PARTIDO_UNIDO = "partido_unido"

# Only the start event comes from the app; the success event is recorded by
# the backend once joining really worked.
EVENTOS_DESDE_LA_APP = {UNION_INICIADA}
PROPS_PERMITIDAS = {"deporte", "como_suplente"}

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


def track(base_datos: Session, evento: str, props: dict | None = None) -> Evento:
    props = {
        clave: valor
        for clave, valor in (props or {}).items()
        if clave in PROPS_PERMITIDAS
    }
    registro = Evento(evento=evento, props=props)
    base_datos.add(registro)
    base_datos.commit()
    base_datos.refresh(registro)
    enviar_a_ga(evento, props)
    return registro


def resumen(base_datos: Session) -> dict:
    conteos = dict(
        base_datos.execute(
            select(Evento.evento, func.count()).group_by(Evento.evento)
        ).all()
    )
    iniciadas = conteos.get(UNION_INICIADA, 0)
    unidas = conteos.get(PARTIDO_UNIDO, 0)
    ultimos = base_datos.scalars(
        select(Evento).order_by(Evento.fecha.desc(), Evento.id.desc()).limit(10)
    ).all()
    return {
        "union_iniciada": iniciadas,
        "partido_unido": unidas,
        "porcentaje_termina": round(unidas * 100 / iniciadas) if iniciadas else 0,
        "ultimos": [
            {"evento": item.evento, "props": item.props, "fecha": item.fecha}
            for item in ultimos
        ],
    }
