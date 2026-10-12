from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "8c9d0e1f2a3b"
down_revision: Union[str, Sequence[str], None] = "54ba0ea2dd71"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "UPDATE partidos SET estado = lower(estado) "
        "WHERE estado IS NOT NULL"
    )
    op.alter_column(
        "partidos",
        "estado",
        server_default="cupos abiertos",
    )
    op.create_table(
        "partido_participantes",
        sa.Column("partido_id", sa.Integer(), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["partido_id"],
            ["partidos.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["usuario_id"],
            ["usuarios.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("partido_id", "usuario_id"),
    )
    op.create_index(
        "ix_partido_participantes_usuario_id",
        "partido_participantes",
        ["usuario_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_partido_participantes_usuario_id",
        table_name="partido_participantes",
    )
    op.drop_table("partido_participantes")
