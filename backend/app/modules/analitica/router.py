from html import escape

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.analitica.service import EVENTOS_DESDE_LA_APP, resumen, track
from app.modules.auth.service import current_user

router = APIRouter(tags=["Analítica"])


class EventoApp(BaseModel):
    evento: str = Field(min_length=1, max_length=50)
    props: dict = {}


@router.post("/api/analitica/eventos", status_code=status.HTTP_201_CREATED)
def registrar_evento(
    datos: EventoApp,
    base_datos: Session = Depends(get_db),
    _usuario: Usuario = Depends(current_user),  # only signed-in users; not stored
):
    if datos.evento not in EVENTOS_DESDE_LA_APP:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"codigo": "EVENTO_NO_PERMITIDO", "mensaje": "Evento desconocido"},
        )
    registro = track(base_datos, datos.evento, datos.props)
    return {"evento": registro.evento, "props": registro.props}


@router.get("/api/analitica/resumen")
def ver_resumen(base_datos: Session = Depends(get_db)):
    return resumen(base_datos)


NOMBRES_FLUJO = {
    "crear_partido": "Crear partido",
    "unirse": "Unirse a un partido",
    "reprogramar": "Reprogramar (Tarea 7)",
    "validar_resultado": "Validar el resultado (Tarea 8)",
    "darse_de_baja": "Darse de baja (Tarea 9)",
}


def _embudo_html(embudo: dict) -> str:
    inicio = embudo["pasos"][0]["cantidad"] or 1
    pasos = ""
    for paso in embudo["pasos"]:
        ancho = min(round(paso["cantidad"] * 100 / inicio), 100)
        caida = (
            f'<span class="caida">↓ {paso["caida"]} % se pierde</span>'
            if paso["caida"]
            else ""
        )
        pasos += (
            f'<div class="paso"><div class="nombre">{escape(paso["evento"])}</div>'
            f'<div class="barra"><div style="width:{ancho}%"></div></div>'
            f'<b>{paso["cantidad"]}</b> {caida}</div>'
        )
    titulo = NOMBRES_FLUJO.get(embudo["flujo"], embudo["flujo"])
    return (
        f'<section class="embudo"><h3>{escape(titulo)} '
        f'<small>termina {embudo["termina"]} %</small></h3>{pasos}</section>'
    )


@router.get("/analitica", response_class=HTMLResponse)
def panel(base_datos: Session = Depends(get_db)):
    datos = resumen(base_datos)
    embudos = "".join(_embudo_html(embudo) for embudo in datos["embudos"])
    mayor = datos["mayor_caida"]
    mayor_html = (
        f'<p class="alerta">Mayor caída: <b>{mayor["caida"]} %</b> antes de '
        f'<code>{escape(mayor["evento"])}</code> en '
        f'{escape(NOMBRES_FLUJO.get(mayor["flujo"], mayor["flujo"]))}.</p>'
        if mayor and mayor["caida"]
        else "<p>Todavía no hay caídas entre pasos.</p>"
    )
    errores = "".join(
        f"<tr><td>{escape(NOMBRES_FLUJO.get(item['flujo'], item['flujo']))}</td>"
        f"<td><code>{escape(item['motivo'])}</code></td><td>{item['cantidad']}</td></tr>"
        for item in datos["errores"]
    )
    filas = "".join(
        f"<li><b>{escape(item['evento'])}</b> "
        f"<span>{escape(', '.join(f'{k}: {v}' for k, v in item['props'].items()))}"
        f" · {item['fecha']:%d/%m %H:%M}</span></li>"
        for item in datos["ultimos"]
    )
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Analítica · UniSport</title>
<style>
 body {{ font-family: system-ui, sans-serif; margin: 24px; color: #1f2933; max-width: 960px; }}
 .embudos {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px; }}
 .embudo {{ border: 1px solid #d0d7de; border-radius: 10px; padding: 12px 16px; }}
 .embudo h3 {{ margin: 0 0 8px; font-size: 16px; }}
 .embudo small {{ color: #2e7d32; font-weight: normal; }}
 .paso {{ margin: 6px 0; font-size: 14px; }}
 .nombre {{ font-family: monospace; color: #57606a; }}
 .barra {{ background: #eef1f4; border-radius: 4px; height: 10px; margin: 2px 0; }}
 .barra div {{ background: #1f6feb; height: 10px; border-radius: 4px; }}
 .caida {{ color: #c62828; }}
 .alerta {{ background: #fdecea; border: 1px solid #c62828; border-radius: 8px; padding: 10px 14px; }}
 table {{ border-collapse: collapse; }} td, th {{ border-bottom: 1px solid #d0d7de; padding: 4px 12px 4px 0; text-align: left; }}
 li {{ margin: 6px 0; }} li span {{ color: #57606a; }}
</style></head><body>
<h1>Analítica · UniSport (solo desarrollo)</h1>
<p>Un embudo por flujo principal: de quienes empiezan, ¿cuántos terminan y en qué paso se pierden?</p>
{mayor_html}
<div class="embudos">{embudos}</div>
<h2>Errores que frenan la tarea</h2>
<table><tr><th>Flujo</th><th>Motivo</th><th>Veces</th></tr>
{errores or '<tr><td colspan="3">Sin errores registrados.</td></tr>'}</table>
<h2>Búsquedas sin resultados: {datos['busquedas_sin_resultados']}</h2>
<h2>Últimos eventos</h2>
<ul>{filas or '<li>Todavía no hay eventos.</li>'}</ul>
</body></html>"""
