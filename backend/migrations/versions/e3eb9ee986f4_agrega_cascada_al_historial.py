"""agrega cascada al historial

Revision ID: e3eb9ee986f4
Revises: d1906c9e294a
Create Date: 2026-10-19 18:57:12.057132

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Identificadores de la revisión, usados por Alembic.
revision: str = 'e3eb9ee986f4'
down_revision: Union[str, Sequence[str], None] = 'd1906c9e294a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Aplica los cambios al esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    op.drop_constraint(op.f('historial_participaciones_partido_id_fkey'), 'historial_participaciones', type_='foreignkey')
    op.drop_constraint(op.f('historial_participaciones_usuario_id_fkey'), 'historial_participaciones', type_='foreignkey')
    op.create_foreign_key(None, 'historial_participaciones', 'partidos', ['partido_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(None, 'historial_participaciones', 'usuarios', ['usuario_id'], ['id'], ondelete='CASCADE')
    # ### Fin de los comandos de Alembic ###


def downgrade() -> None:
    """Revierte los cambios del esquema de la base de datos."""
    # ### Comandos generados automáticamente por Alembic; ajústalos si hace falta ###
    # ADVERTENCIA: la restricción no tiene nombre; esta instrucción fallará
    # tal como está. Ponle un nombre o usa una convención de nombres; ver
    # https://alembic.sqlalchemy.org/en/latest/naming.html
    op.drop_constraint(None, 'historial_participaciones', type_='foreignkey')
    # ADVERTENCIA: la restricción no tiene nombre; esta instrucción fallará
    # tal como está. Ponle un nombre o usa una convención de nombres; ver
    # https://alembic.sqlalchemy.org/en/latest/naming.html
    op.drop_constraint(None, 'historial_participaciones', type_='foreignkey')
    op.create_foreign_key(op.f('historial_participaciones_usuario_id_fkey'), 'historial_participaciones', 'usuarios', ['usuario_id'], ['id'])
    op.create_foreign_key(op.f('historial_participaciones_partido_id_fkey'), 'historial_participaciones', 'partidos', ['partido_id'], ['id'])
    # ### Fin de los comandos de Alembic ###
