from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.auth.service import current_user
from app.modules.cuenta.service import mis_datos

router = APIRouter(prefix="/api/cuenta", tags=["Mi cuenta"])


@router.get("/mis-datos")
def ver_mis_datos(
    base_datos: Session = Depends(get_db),
    usuario: Usuario = Depends(current_user),
):
    return mis_datos(usuario, base_datos)
