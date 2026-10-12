"""agrega cantidad de jugadores a partidos

Revision ID: b4c8d2e6f901
Revises: 7f3a1c2d9e4b
Create Date: 2026-10-01 22:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b4c8d2e6f901"
down_revision: Union[str, Sequence[str], None] = "7f3a1c2d9e4b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "partidos",
        sa.Column(
            "cantidad_jugadores",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.alter_column(
        "partidos",
        "cantidad_jugadores",
        server_default=None,
    )


def downgrade() -> None:
    op.drop_column("partidos", "cantidad_jugadores")
