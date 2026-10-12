"""agrega deporte a partidos

Revision ID: 61781f07301f
Revises: 8c9d0e1f2a3b
Create Date: 2026-10-11 21:59:49.603657

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '61781f07301f'
down_revision: Union[str, Sequence[str], None] = '8c9d0e1f2a3b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'partidos',
        sa.Column(
            'deporte',
            sa.String(length=50),
            server_default='futbol',
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column('partidos', 'deporte')
