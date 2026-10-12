"""estas son las endpoints que expone el backend para los use el frontend y se haga login"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.auth.schemas import (
    AuthResponse,
    LoginData,
    NewPasswordData,
    PasswordData,
    RecoveryData,
    UsuarioCreate,
    UsuarioResponse,
)
from app.modules.auth.service import (
    change_user_password,
    create_token,
    create_user,
    current_user,
    login_user,
    recover_account,
    reset_user_password,
    user_data,
)


router = APIRouter(prefix="/api/auth", tags=["Autenticación"])


@router.post(
    "/registro",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(data: UsuarioCreate, db: Session = Depends(get_db)):
    user = create_user(data, db)
    return AuthResponse(access_token=create_token(user.id), usuario=user_data(user))


@router.post("/login", response_model=AuthResponse)
def login(data: LoginData, db: Session = Depends(get_db)):
    user = login_user(data, db)
    return AuthResponse(access_token=create_token(user.id), usuario=user_data(user))


@router.get("/yo", response_model=UsuarioResponse)
def me(user: Usuario = Depends(current_user)):
    return user_data(user)


@router.post("/cambiar-password-auth")
def change_password(
    data: PasswordData,
    user: Usuario = Depends(current_user),
    db: Session = Depends(get_db),
):
    change_user_password(data, user, db)
    return {"mensaje": "Contraseña actualizada"}


@router.post("/recuperar")
def recovery(data: RecoveryData, db: Session = Depends(get_db)):
    token = recover_account(data, db)
    return {"mensaje": "Token generado para recuperar contraseña", "token": token}


@router.post("/cambiar-password")
def reset_password(data: NewPasswordData, db: Session = Depends(get_db)):
    reset_user_password(data, db)
    return {"mensaje": "Contraseña actualizada"}
