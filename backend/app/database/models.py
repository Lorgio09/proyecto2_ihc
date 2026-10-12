from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(120), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    telefono: Mapped[str | None] = mapped_column(String(20), nullable=True)
    token_recuperacion: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    token_expiracion: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    partidos: Mapped[list["Partido"]] = relationship(
        back_populates="usuario",
        cascade="all, delete-orphan",
    )


class Partido(Base):
    __tablename__ = "partidos"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )
    nombre: Mapped[str] = mapped_column(String(100))
    cantidad_jugadores: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    ubicacion: Mapped[str] = mapped_column(String(255))
    tiempo_min: Mapped[str | None] = mapped_column(String(20), nullable=True)
    fecha: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    estado: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="Cupos abiertos",
        server_default="Cupos abiertos",
    )

    usuario: Mapped[Usuario] = relationship(back_populates="partidos")
