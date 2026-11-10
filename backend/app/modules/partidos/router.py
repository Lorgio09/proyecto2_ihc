from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.auth.service import current_user
from app.modules.partidos.schemas import (
    ActualizacionPartido,
    DatosPartido,
    RespuestaHistorial,
    RespuestaPartido,
    RespuestaPartidoExplorar,
    Reprogramacion,
    Disputa,
    Marcador,
    PropuestaEquipos,
    RespuestaValidacion,
)
from app.modules.partidos.resultado import (
    aceptar_equipos,
    confirmar_resultado,
    datos_validacion,
    disputar_resultado,
    listar_partidos_participando,
    proponer_equipos,
    puede_ver,
    registrar_resultado,
)
from app.modules.partidos.service import (
    buscar_partido,
    buscar_partido_publico,
    crear_partido,
    completar_equipo as completar_equipo_servicio,
    datos_partido,
    datos_partido_publico,
    eliminar_partido,
    listar_historial,
    listar_partidos,
    listar_partidos_publicos,
    ErrorPartido,
    reabrir_equipo,
    reconfirmar_partido,
    reprogramar_partido,
    salir_partido,
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
    try:
        return datos_partido(crear_partido(datos, usuario, base_datos))
    except ErrorPartido as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )


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


@router.get("/historial", response_model=list[RespuestaHistorial])
def obtener_historial(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return listar_historial(usuario, base_datos)


@router.get("/participando", response_model=list[RespuestaPartidoExplorar])
def participando(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return [
        datos_partido_publico(partido)
        for partido in listar_partidos_participando(usuario, base_datos)
    ]


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
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
                if error.codigo == "FECHA_NO_FUTURA"
                else status.HTTP_409_CONFLICT
            ),
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


@router.patch("/{partido_id}/reabrir", response_model=RespuestaPartido)
def reabrir(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido(partido_id, usuario, base_datos)
    if not partido:
        raise no_encontrado()
    try:
        return datos_partido(reabrir_equipo(partido, base_datos))
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


@router.delete("/{partido_id}/salir", response_model=RespuestaPartido)
def salir(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    try:
        partido = salir_partido(partido_id, usuario, base_datos)
        if not partido:
            raise no_encontrado()
        return datos_partido(partido)
    except ErrorPartido as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )


@router.patch("/{partido_id}/reprogramar", response_model=RespuestaPartido)
def reprogramar(
    partido_id: int,
    datos: Reprogramacion,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = buscar_partido(partido_id, usuario, base_datos)
    if not partido:
        raise no_encontrado()
    try:
        return datos_partido(reprogramar_partido(partido, datos, base_datos))
    except ErrorPartido as error:
        codigo_http = (
            status.HTTP_409_CONFLICT
            if error.codigo == "REPROGRAMACION_PENDIENTE"
            else status.HTTP_422_UNPROCESSABLE_ENTITY
        )
        raise HTTPException(
            status_code=codigo_http,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )


@router.post("/{partido_id}/reconfirmar", response_model=RespuestaPartido)
def reconfirmar(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    try:
        partido = reconfirmar_partido(partido_id, usuario, base_datos)
        if not partido:
            raise no_encontrado()
        return datos_partido(partido)
    except ErrorPartido as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"codigo": error.codigo, "mensaje": error.mensaje},
        )


# --- Result validation -----------------------------------------------------

ERRORES_DE_PERMISO = {"SOLO_CAPITAN", "SOLO_ORGANIZADOR"}
ERRORES_DE_DATOS = {"MOTIVO_OBLIGATORIO", "MARCADOR_INVALIDO", "EQUIPOS_INVALIDOS"}


def error_validacion(error: ErrorPartido) -> HTTPException:
    if error.codigo in ERRORES_DE_PERMISO:
        codigo_http = status.HTTP_403_FORBIDDEN
    elif error.codigo in ERRORES_DE_DATOS:
        codigo_http = status.HTTP_422_UNPROCESSABLE_ENTITY
    else:
        codigo_http = status.HTTP_409_CONFLICT
    return HTTPException(
        status_code=codigo_http,
        detail={"codigo": error.codigo, "mensaje": error.mensaje},
    )


def partido_visible(partido_id: int, usuario: Usuario, base_datos: Session):
    partido = buscar_partido_publico(partido_id, base_datos)
    if not partido or not puede_ver(partido, usuario):
        raise no_encontrado()
    return partido


def partido_del_organizador(partido_id: int, usuario: Usuario, base_datos: Session):
    partido = partido_visible(partido_id, usuario, base_datos)
    if partido.usuario_id != usuario.id:
        raise error_validacion(
            ErrorPartido("SOLO_ORGANIZADOR", "Solo el organizador puede hacer esto")
        )
    return partido


@router.get("/{partido_id}/validacion", response_model=RespuestaValidacion)
def validacion(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return datos_validacion(partido_visible(partido_id, usuario, base_datos), usuario)


@router.put("/{partido_id}/equipos", response_model=RespuestaValidacion)
def proponer(
    partido_id: int,
    datos: PropuestaEquipos,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = partido_del_organizador(partido_id, usuario, base_datos)
    try:
        partido = proponer_equipos(
            partido, datos.equipo_b, datos.capitan_rival_id, base_datos
        )
    except ErrorPartido as error:
        raise error_validacion(error)
    return datos_validacion(partido, usuario)


@router.post("/{partido_id}/equipos/aceptar", response_model=RespuestaValidacion)
def aceptar(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido_visible(partido_id, usuario, base_datos)
    try:
        partido = aceptar_equipos(partido_id, usuario, base_datos)
    except ErrorPartido as error:
        raise error_validacion(error)
    return datos_validacion(partido, usuario)


@router.post("/{partido_id}/resultados", response_model=RespuestaValidacion)
def registrar(
    partido_id: int,
    datos: Marcador,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido = partido_del_organizador(partido_id, usuario, base_datos)
    try:
        partido = registrar_resultado(partido, datos.goles_a, datos.goles_b, base_datos)
    except ErrorPartido as error:
        raise error_validacion(error)
    return datos_validacion(partido, usuario)


@router.post("/{partido_id}/resultados/confirmar", response_model=RespuestaValidacion)
def confirmar(
    partido_id: int,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido_visible(partido_id, usuario, base_datos)
    try:
        partido = confirmar_resultado(partido_id, usuario, base_datos)
    except ErrorPartido as error:
        raise error_validacion(error)
    return datos_validacion(partido, usuario)


@router.post("/{partido_id}/resultados/disputar", response_model=RespuestaValidacion)
def disputar(
    partido_id: int,
    datos: Disputa,
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    partido_visible(partido_id, usuario, base_datos)
    try:
        partido = disputar_resultado(partido_id, usuario, datos.motivo, base_datos)
    except ErrorPartido as error:
        raise error_validacion(error)
    return datos_validacion(partido, usuario)
