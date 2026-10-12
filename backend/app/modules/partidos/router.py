from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.auth.service import current_user
from app.modules.partidos.schemas import (
    ActualizacionPartido,
    DatosPartido,
    RespuestaPartido,
    RespuestaPartidoExplorar,
)
from app.modules.partidos.service import (
    buscar_partido,
    buscar_partido_publico,
    crear_partido,
    completar_equipo as completar_equipo_servicio,
    datos_partido,
    datos_partido_publico,
    eliminar_partido,
    listar_partidos,
    listar_partidos_publicos,
    ErrorPartido,
    unirse_partido,
    actualizar_partido,
)


router = APIRouter(prefix="/api/partidos", tags=["Partidos"])


def no_encontrado() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Partido no encontrado",
    )


@router.post("", response_model=RespuestaPartido, status_code=status.HTTP_201_CREATED)
def crear(
    datos: DatosPartido,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return datos_partido(crear_partido(datos, usuario, base_datos))


@router.get("", response_model=list[RespuestaPartido])
def listar(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return [datos_partido(partido) for partido in listar_partidos(usuario, base_datos)]


@router.get("/explorar", response_model=list[RespuestaPartidoExplorar])
def explorar(
    busqueda: str | None = Query(default=None),
    deporte: str | None = Query(default=None),
    zona: str | None = Query(default=None),
    desde: date | None = Query(default=None),
    hasta: date | None = Query(default=None),
    solo_con_cupos: bool = Query(default=False),
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return [
        datos_partido_publico(partido)
        for partido in listar_partidos_publicos(
            usuario=usuario,
            base_datos=base_datos,
            busqueda=busqueda,
            deporte=deporte,
            zona=zona,
            desde=desde,
            hasta=hasta,
            solo_con_cupos=solo_con_cupos,
        )
    ]


@router.get("/explorar/{partido_id}", response_model=RespuestaPartidoExplorar)
def explorar_uno(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido_publico(partido_id, base_datos)
    if not partido or partido.usuario_id == usuario.id:
        raise no_encontrado()
    return datos_partido_publico(partido)


@router.get("/{partido_id}", response_model=RespuestaPartido)
def obtener(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido(partido_id, usuario, base_datos)
    if not partido:
        raise no_encontrado()
    return datos_partido(partido)


@router.put("/{partido_id}", response_model=RespuestaPartido)
def actualizar(
    partido_id: int,
    datos: ActualizacionPartido,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido(partido_id, usuario, base_datos)
    if not partido:
        raise no_encontrado()
    try:
        return datos_partido(actualizar_partido(partido, datos, base_datos))
    except ErrorPartido as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )


@router.delete("/{partido_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido(partido_id, usuario, base_datos)
    if not partido:
        raise no_encontrado()
    eliminar_partido(partido, base_datos)


@router.patch("/{partido_id}/completar", response_model=RespuestaPartido)
def completar_equipo(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido(partido_id, usuario, base_datos)
    if not partido:
        raise no_encontrado()
    try:
        return datos_partido(completar_equipo_servicio(partido, base_datos))

    except ErrorPartido as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )


@router.post("/{partido_id}/unirse", response_model=RespuestaPartido)
def unirse(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    try:
        partido = unirse_partido(partido_id, usuario, base_datos)
        if not partido:
            raise no_encontrado()
        return datos_partido(partido)
    except ErrorPartido as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )
