"""agrega suplentes a participantes

Revision ID: a7d3f1c8b2e5
Revises: e3eb9ee986f4
Create Date: 2026-10-31 19:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a7d3f1c8b2e5"
down_revision: Union[str, Sequence[str], None] = "e3eb9ee986f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Existing participants are all holders and share the migration time.
    op.add_column(
        "partido_participantes",
        sa.Column(
            "es_suplente",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "partido_participantes",
        sa.Column(
            "unido_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_column("partido_participantes", "unido_en")
    op.drop_column("partido_participantes", "es_suplente")
