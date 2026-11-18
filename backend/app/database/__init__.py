"""Paquete de la base de datos: conexión y modelos."""

from app.database.connection import Base, get_db

__all__ = ["Base", "get_db"]
