"""crea tabla usuarios

Revision ID: cc7ef5519793
Revises: 
Create Date: 2026-09-30 20:35:46.024023

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de la revisión, usados por Alembic.
revision: str = 'cc7ef5519793'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Aplica los cambios al esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    op.create_table('usuarios',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('nombre', sa.String(length=100), nullable=False),
    sa.Column('email', sa.String(length=120), nullable=False),
    sa.Column('password_hash', sa.String(length=255), nullable=False),
    sa.Column('telefono', sa.String(length=20), nullable=True),
    sa.Column('token_recuperacion', sa.String(length=255), nullable=True),
    sa.Column('token_expiracion', sa.DateTime(timezone=True), nullable=True),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('email')
    )
    # ### Fin de los comandos de Alembic ###


def downgrade() -> None:
    """Revierte los cambios del esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    op.drop_table('usuarios')
    # ### Fin de los comandos de Alembic ###
