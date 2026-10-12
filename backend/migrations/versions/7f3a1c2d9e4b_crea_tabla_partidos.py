"""crea tabla partidos

Revision ID: 7f3a1c2d9e4b
Revises: cc7ef5519793
Create Date: 2026-10-01 21:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "7f3a1c2d9e4b"
down_revision: Union[str, Sequence[str], None] = "cc7ef5519793"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "partidos",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("nombre", sa.String(length=100), nullable=False),
        sa.Column("ubicacion", sa.String(length=255), nullable=False),
        sa.Column("tiempo_min", sa.String(length=20), nullable=True),
        sa.Column("fecha", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_partidos_usuario_id"),
        "partidos",
        ["usuario_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_partidos_usuario_id"), table_name="partidos")
    op.drop_table("partidos")
