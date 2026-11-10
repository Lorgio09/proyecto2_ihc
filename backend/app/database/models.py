from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, false, func
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
        foreign_keys="Partido.usuario_id",
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

    # Motivo de la última reprogramación (fecha o lugar cambiados)
    motivo_reprogramacion: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )

    # Result validation: the organizer proposes teams and a rival captain,
    # who accepts them before the match and later validates the score.
    capitan_rival_id: Mapped[int | None] = mapped_column(
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    equipos_aceptados: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=false(),
    )

    usuario: Mapped[Usuario] = relationship(
        back_populates="partidos", foreign_keys=[usuario_id]
    )
    capitan_rival: Mapped[Usuario | None] = relationship(
        foreign_keys=[capitan_rival_id]
    )
    resultados: Mapped[list["ResultadoPartido"]] = relationship(
        back_populates="partido",
        cascade="all, delete-orphan",
        order_by="ResultadoPartido.version",
    )
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

    # Holders fill the match up to its capacity; whoever joins after that waits
    # as a substitute, ordered by unido_en.
    es_suplente: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=false(),
    )
    unido_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
    # After a reschedule, holders keep their spot while they reconfirm.
    pendiente_confirmar: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=false(),
    )

    # "A" or "B" once the organizer proposes the teams.
    equipo: Mapped[str | None] = mapped_column(String(1), nullable=True)

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


class ResultadoPartido(Base):
    """One score version. A correction adds a new version; none is deleted."""

    __tablename__ = "partido_resultados"

    id: Mapped[int] = mapped_column(primary_key=True)
    partido_id: Mapped[int] = mapped_column(
        ForeignKey("partidos.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    goles_a: Mapped[int] = mapped_column(Integer, nullable=False)
    goles_b: Mapped[int] = mapped_column(Integer, nullable=False)
    # pendiente -> confirmado | disputado
    estado: Mapped[str] = mapped_column(String(20), nullable=False)
    motivo_disputa: Mapped[str | None] = mapped_column(String(255), nullable=True)
    registrado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    respondido_en: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    partido: Mapped[Partido] = relationship(back_populates="resultados")
