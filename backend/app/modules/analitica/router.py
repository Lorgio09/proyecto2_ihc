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


@router.get("/analitica", response_class=HTMLResponse)
def panel(base_datos: Session = Depends(get_db)):
    datos = resumen(base_datos)
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
 body {{ font-family: system-ui, sans-serif; margin: 24px; color: #1f2933; }}
 .tarjetas {{ display: flex; gap: 12px; flex-wrap: wrap; }}
 .tarjeta {{ border: 1px solid #d0d7de; border-radius: 10px; padding: 16px 20px; min-width: 150px; }}
 .tarjeta b {{ font-size: 32px; display: block; }}
 .destacada {{ background: #e6f4ea; border-color: #2e7d32; }}
 li {{ margin: 6px 0; }} li span {{ color: #57606a; }}
</style></head><body>
<h1>Analítica · UniSport (solo desarrollo)</h1>
<p>Pregunta: <i>de quienes empiezan a unirse a un partido, ¿cuántos lo terminan?</i></p>
<div class="tarjetas">
 <div class="tarjeta"><b>{datos['union_iniciada']}</b>union_iniciada</div>
 <div class="tarjeta"><b>{datos['partido_unido']}</b>partido_unido</div>
 <div class="tarjeta destacada"><b>{datos['porcentaje_termina']} %</b>terminan</div>
</div>
<h2>Últimos eventos</h2>
<ul>{filas or '<li>Todavía no hay eventos.</li>'}</ul>
</body></html>"""
