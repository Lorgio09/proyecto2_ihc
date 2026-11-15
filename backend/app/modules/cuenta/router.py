from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.analitica.service import CUENTA_ELIMINADA, registrar, registrar_fallo
from app.modules.auth.service import current_user
from app.modules.cuenta.service import (
    ErrorCuenta,
    bloqueos_eliminacion,
    consecuencias_eliminacion,
    eliminar_cuenta,
    mis_datos,
)

router = APIRouter(prefix="/api/cuenta", tags=["Mi cuenta"])


@router.get("/mis-datos")
def ver_mis_datos(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return mis_datos(usuario, base_datos)


@router.get("/eliminacion")
def antes_de_eliminar(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    """What deleting the account would do, or what stops it, before asking."""
    bloqueos = bloqueos_eliminacion(usuario, base_datos)
    return {
        "puede_eliminar": not bloqueos,
        "bloqueos": bloqueos,
        "consecuencias": consecuencias_eliminacion(usuario, base_datos),
    }


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    try:
        eliminar_cuenta(usuario, base_datos)
    except ErrorCuenta as error:
        registrar_fallo(base_datos, "eliminar_cuenta", error.codigo)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "codigo": error.codigo,
                "mensaje": error.mensaje,
                "bloqueos": error.bloqueos,
            },
        )
    registrar(base_datos, CUENTA_ELIMINADA)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
