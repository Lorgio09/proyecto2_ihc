"""crea tabla eventos

Revision ID: d4f6a2b8c913
Revises: c8a1d5e7f302
Create Date: 2026-11-10 20:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "d4f6a2b8c913"
down_revision: Union[str, Sequence[str], None] = "c8a1d5e7f302"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "eventos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("evento", sa.String(length=50), nullable=False),
        sa.Column("props", sa.JSON(), nullable=False),
        sa.Column(
            "fecha",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_eventos_evento", "eventos", ["evento"])


def downgrade() -> None:
    op.drop_index("ix_eventos_evento", table_name="eventos")
    op.drop_table("eventos")
