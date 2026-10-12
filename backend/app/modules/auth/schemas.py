from pydantic import BaseModel, Field


class UsuarioCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    email: str = Field(min_length=3, max_length=120)
    password: str = Field(min_length=6, max_length=72)
    telefono: str | None = Field(default=None, max_length=20)


class UsuarioResponse(BaseModel):
    id: int
    nombre: str
    email: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioResponse


class LoginData(BaseModel):
    email: str = Field(min_length=3, max_length=120)
    password: str = Field(min_length=1, max_length=72)


class RecoveryData(BaseModel):
    email: str = Field(min_length=3, max_length=120)


class NewPasswordData(BaseModel):
    token: str = Field(min_length=1)
    nueva_password: str = Field(min_length=6, max_length=72)


class PasswordData(BaseModel):
    contrasena_actual: str = Field(min_length=1, max_length=72)
    nueva_password: str = Field(min_length=6, max_length=72)
