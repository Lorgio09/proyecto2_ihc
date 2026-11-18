import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


def _url_base_datos(url: str) -> str:
    """Los servicios en la nube (Render, Neon, Heroku) entregan postgres:// o postgresql://;
    SQLAlchemy necesita que se indique explícitamente el driver psycopg 3."""
    for prefijo in ("postgres://", "postgresql://"):
        if url.startswith(prefijo):
            return "postgresql+psycopg://" + url[len(prefijo):]
    return url


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "UniSport API")
    database_url: str = _url_base_datos(os.getenv("DATABASE_URL", ""))
    secret_key: str = os.getenv("SECRET_KEY", "")
    ga_measurement_id: str = os.getenv("GA_MEASUREMENT_ID", "")
    ga_api_secret: str = os.getenv("GA_API_SECRET", "")


settings = Settings()
