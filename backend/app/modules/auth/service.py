
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.auth.schemas import (
    LoginData,
    NewPasswordData,
    PasswordData,
    RecoveryData,
    UsuarioCreate,
    UsuarioResponse,
)


security = HTTPBearer()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def check_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode(), password_hash.encode())


def create_token(user_id: int) -> str:
    data = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(days=1),
    }
    return jwt.encode(data, settings.secret_key, algorithm="HS256")


def read_token(token: str) -> int:
    data = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    return int(data["sub"])


def get_user(token: str, db: Session) -> Usuario:
    try:
        user_id = read_token(token)
    except (jwt.InvalidTokenError, KeyError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido",
        )

    user = db.get(Usuario, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado",
        )

    return user


def current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> Usuario:
    return get_user(credentials.credentials, db)


def user_data(user: Usuario) -> UsuarioResponse:
    return UsuarioResponse(id=user.id, nombre=user.nombre, email=user.email)


def create_user(data: UsuarioCreate, db: Session) -> Usuario:
    email = data.email.lower().strip()
    old_user = db.scalar(select(Usuario).where(Usuario.email == email))
    if old_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El email ya está registrado",
        )

    user = Usuario(
        nombre=data.nombre.strip(),
        email=email,
        password_hash=hash_password(data.password),
        telefono=data.telefono,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def login_user(data: LoginData, db: Session) -> Usuario:
    user = db.scalar(
        select(Usuario).where(Usuario.email == data.email.lower().strip())
    )
    if not user or not check_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
        )
    return user


def change_user_password(
    data: PasswordData,
    user: Usuario,
    db: Session,
) -> None:
    if not check_password(data.contrasena_actual, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="La contraseña actual es incorrecta",
        )
    if data.contrasena_actual == data.nueva_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La nueva contraseña debe ser distinta a la actual",
        )

    user.password_hash = hash_password(data.nueva_password)
    db.commit()


def recover_account(data: RecoveryData, db: Session) -> str:
    user = db.scalar(
        select(Usuario).where(Usuario.email == data.email.lower().strip())
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )

    token = "123456"
    user.token_recuperacion = token
    user.token_expiracion = datetime.now(timezone.utc) + timedelta(minutes=15)
    db.commit()
    return token


def reset_user_password(data: NewPasswordData, db: Session) -> None:
    user = db.scalar(
        select(Usuario).where(Usuario.token_recuperacion == data.token)
    )
    if (
        not user
        or not user.token_expiracion
        or user.token_expiracion < datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token inválido o vencido",
        )

    user.password_hash = hash_password(data.nueva_password)
    user.token_recuperacion = None
    user.token_expiracion = None
    db.commit()
