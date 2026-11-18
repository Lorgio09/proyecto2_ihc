"""agrega columna estado a partidos

Revision ID: 54ba0ea2dd71
Revises: 0e0efd554795
Create Date: 2026-10-06 01:14:29.384443

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de la revisión, usados por Alembic.
revision: str = '54ba0ea2dd71'
down_revision: Union[str, Sequence[str], None] = '0e0efd554795'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Aplica los cambios al esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    op.add_column('partidos', sa.Column('estado', sa.String(length=20), server_default='Cupos abiertos', nullable=False))
    # ### Fin de los comandos de Alembic ###


def downgrade() -> None:
    """Revierte los cambios del esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    op.drop_column('partidos', 'estado')
    # ### Fin de los comandos de Alembic ###
