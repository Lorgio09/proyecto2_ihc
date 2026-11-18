"""agrega reprogramacion de partidos

Revision ID: b5e9c2d4f7a1
Revises: a7d3f1c8b2e5
Create Date: 2026-11-05 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de la revisión, usados por Alembic.
revision: str = "b5e9c2d4f7a1"
down_revision: Union[str, Sequence[str], None] = "a7d3f1c8b2e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "partidos",
        sa.Column("motivo_reprogramacion", sa.String(length=255), nullable=True),
    )
    # Los participantes que ya existían no tienen nada que reconfirmar.
    op.add_column(
        "partido_participantes",
        sa.Column(
            "pendiente_confirmar",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column("partido_participantes", "pendiente_confirmar")
    op.drop_column("partidos", "motivo_reprogramacion")
