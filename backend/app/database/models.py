from datetime import datetime, timezone

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
    partidos_participados: Mapped[list["PartidoParticipante"]] = relationship(
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

    deporte: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="futbol",
        server_default="futbol",
    )

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
        default="cupos abiertos",
        server_default="cupos abiertos",
    )

    usuario: Mapped[Usuario] = relationship(back_populates="partidos")
    participantes: Mapped[list["PartidoParticipante"]] = relationship(
        back_populates="partido",
        cascade="all, delete-orphan",
    )


class PartidoParticipante(Base):
    __tablename__ = "partido_participantes"

    partido_id: Mapped[int] = mapped_column(
        ForeignKey("partidos.id", ondelete="CASCADE"),
        primary_key=True,
    )
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )

    partido: Mapped[Partido] = relationship(back_populates="participantes")
    usuario: Mapped[Usuario] = relationship(back_populates="partidos_participados")

class HistorialParticipacion(Base):
    __tablename__ = "historial_participaciones"

    id: Mapped[int] = mapped_column(primary_key=True)

    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    partido_id: Mapped[int] = mapped_column(
        ForeignKey("partidos.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    accion: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="se_unio",
    )

    fecha_evento: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )