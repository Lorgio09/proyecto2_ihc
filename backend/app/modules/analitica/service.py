"""Analítica de interacción: una sola función, track(), registra lo que pasó.

Solo se registra la acción, nunca la persona: ni id de usuario, ni email, ni texto libre.
Cada evento se guarda en la tabla `eventos` y, cuando GA_MEASUREMENT_ID y
GA_API_SECRET están configurados, también se envía a Google Analytics 4.

El plan de eventos (evento, flujo, archivo:línea y pregunta) está en
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
MIS_DATOS_VISTOS = "mis_datos_vistos"
MIS_DATOS_DESCARGADOS = "mis_datos_descargados"
ELIMINACION_INICIADA = "eliminacion_iniciada"
CUENTA_ELIMINADA = "cuenta_eliminada"

# Un embudo por cada flujo principal: inicio -> (pasos intermedios) -> éxito.
EMBUDOS = {
    "crear_partido": [PARTIDO_CREACION_INICIADA, PARTIDO_CREADO],
    "unirse": [UNION_INICIADA, PARTIDO_UNIDO],
    "reprogramar": [REPROGRAMACION_INICIADA, PARTIDO_REPROGRAMADO],
    "validar_resultado": [RESULTADO_REGISTRADO, RESULTADO_CONFIRMADO],
    "darse_de_baja": [BAJA_INICIADA, BAJA_REGISTRADA],
    "descargar_datos": [MIS_DATOS_VISTOS, MIS_DATOS_DESCARGADOS],
    "eliminar_cuenta": [ELIMINACION_INICIADA, CUENTA_ELIMINADA],
}

# Lista fija de motivos por los que una tarea puede fallar: los códigos de error
# de la API más las validaciones que hace la app antes de llamarla. Cualquier otro se guarda como OTRO.
MOTIVOS = {
    # Validación
    "CAMPOS_INCOMPLETOS", "FECHA_OBLIGATORIA", "FECHA_NO_FUTURA", "FECHA_PASADA",
    "FECHA_NO_DISPONIBLE", "MOTIVO_OBLIGATORIO", "SIN_CAMBIOS", "MARCADOR_INVALIDO",
    "EQUIPOS_INVALIDOS", "CAPACIDAD_INSUFICIENTE",
    # Estado del partido
    "EQUIPO_COMPLETO", "EQUIPO_ABIERTO", "YA_INSCRITO", "NO_INSCRITO",
    "PARTIDO_YA_JUGADO", "PARTIDO_NO_TERMINADO", "REPROGRAMACION_PENDIENTE",
    "SIN_RECONFIRMACION", "EQUIPOS_ACEPTADOS", "EQUIPOS_BLOQUEADOS",
    "EQUIPOS_NO_PROPUESTOS", "EQUIPOS_SIN_ACEPTAR", "EQUIPOS_YA_ACEPTADOS",
    "RESULTADO_PENDIENTE", "RESULTADO_CONFIRMADO", "SIN_RESULTADO_PENDIENTE",
    # Permiso denegado
    "SOLO_ORGANIZADOR", "SOLO_CAPITAN", "ORGANIZADOR_NO_PUEDE_UNIRSE",
    "ORGANIZADOR_NO_PUEDE_SALIR", "CAPITAN_NO_PUEDE_SALIR",
    # Eliminación de cuenta bloqueada por la regla de UniSport
    "ORGANIZA_PARTIDOS_CON_JUGADORES", "CAPITAN_CON_RESULTADO_PENDIENTE",
}

# Desde la app solo llegan los eventos de inicio y sus propios fallos de validación;
# cada éxito lo registra el backend una vez que quedó guardado.
EVENTOS_DESDE_LA_APP = {
    UNION_INICIADA,
    PARTIDO_CREACION_INICIADA,
    REPROGRAMACION_INICIADA,
    BAJA_INICIADA,
    TAREA_FALLIDA,
    # El archivo se escribe en el teléfono, así que ambos pasos ocurren en la app.
    MIS_DATOS_VISTOS,
    MIS_DATOS_DESCARGADOS,
    ELIMINACION_INICIADA,
}
PROPS_PERMITIDAS = {"deporte", "como_suplente", "tardia", "flujo", "motivo", "filtros"}

GA_URL = "https://www.google-analytics.com/mp/collect"

log = logging.getLogger(__name__)


def enviar_a_ga(evento: str, props: dict) -> None:
    """Envía el evento a GA4 sin bloquear la petición; los fallos se registran en el log."""
    if not settings.ga_measurement_id or not settings.ga_api_secret:
        return

    # Los parámetros de GA deben ser texto o números.
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
        except Exception as error:  # GA nunca debe romper la app
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
    """track() para los manejadores de peticiones: un fallo de analítica nunca los rompe."""
    try:
        track(base_datos, evento, props)
    except Exception as error:
        log.warning("No se pudo registrar %s: %s", evento, error)


def registrar_fallo(base_datos: Session, flujo: str, motivo: str) -> None:
    """Registra una tarea que falló. Primero descarta los cambios no guardados de la
    petición y nunca lanza excepciones: la analítica no debe ocultar el error real."""
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
            # Un éxito puede llegar sin su inicio (la app envía los inicios en
            # segundo plano), así que un paso nunca muestra una caída negativa.
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
