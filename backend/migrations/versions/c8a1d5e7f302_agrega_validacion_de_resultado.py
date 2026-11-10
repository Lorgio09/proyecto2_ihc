"""agrega validacion de resultado

Revision ID: c8a1d5e7f302
Revises: b5e9c2d4f7a1
Create Date: 2026-11-10 15:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c8a1d5e7f302"
down_revision: Union[str, Sequence[str], None] = "b5e9c2d4f7a1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "partidos",
        sa.Column(
            "capitan_rival_id",
            sa.Integer(),
            sa.ForeignKey(
                "usuarios.id",
                name="fk_partidos_capitan_rival",
                ondelete="SET NULL",
            ),
            nullable=True,
        ),
    )
    op.add_column(
        "partidos",
        sa.Column(
            "equipos_aceptados",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "partido_participantes",
        sa.Column("equipo", sa.String(length=1), nullable=True),
    )
    op.create_table(
        "partido_resultados",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "partido_id",
            sa.Integer(),
            sa.ForeignKey("partidos.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("goles_a", sa.Integer(), nullable=False),
        sa.Column("goles_b", sa.Integer(), nullable=False),
        sa.Column("estado", sa.String(length=20), nullable=False),
        sa.Column("motivo_disputa", sa.String(length=255), nullable=True),
        sa.Column("registrado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("respondido_en", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_partido_resultados_partido_id",
        "partido_resultados",
        ["partido_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_partido_resultados_partido_id", table_name="partido_resultados")
    op.drop_table("partido_resultados")
    op.drop_column("partido_participantes", "equipo")
    op.drop_column("partidos", "equipos_aceptados")
    op.drop_constraint("fk_partidos_capitan_rival", "partidos", type_="foreignkey")
    op.drop_column("partidos", "capitan_rival_id")
