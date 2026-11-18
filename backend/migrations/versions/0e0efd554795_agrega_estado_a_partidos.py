"""agrega estado a partidos

Revision ID: 0e0efd554795
Revises: b4c8d2e6f901
Create Date: 2026-10-05 20:22:06.518892

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de la revisión, usados por Alembic.
revision: str = '0e0efd554795'
down_revision: Union[str, Sequence[str], None] = 'b4c8d2e6f901'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Aplica los cambios al esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    pass
    # ### Fin de los comandos de Alembic ###


def downgrade() -> None:
    """Revierte los cambios del esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    pass
    # ### Fin de los comandos de Alembic ###
