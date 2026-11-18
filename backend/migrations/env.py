from logging.config import fileConfig
from pathlib import Path
import sys

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.config import settings
from app.database.connection import Base
from app.database import models

# Objeto de configuración de Alembic; da acceso
# a los valores del archivo .ini que se está usando.
config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url)

# Lee el archivo de configuración para el logging de Python.
# Básicamente, esta línea prepara los loggers.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# Otros valores de la configuración, según lo que necesite env.py,
# se pueden obtener así:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Ejecuta las migraciones en modo 'offline' (sin conexión).

    Configura el contexto solo con una URL y no con un Engine,
    aunque aquí también se aceptaría un Engine. Como no se crea
    el Engine, ni siquiera hace falta tener un DBAPI disponible.

    Las llamadas a context.execute() escriben el texto recibido
    en la salida del script.

    """
    url = settings.database_url
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Ejecuta las migraciones en modo 'online' (con conexión).

    En este caso hay que crear un Engine
    y asociar una conexión al contexto.

    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
