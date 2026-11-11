import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "UniSport API")
    database_url: str = os.getenv("DATABASE_URL", "")
    secret_key: str = os.getenv("SECRET_KEY", "")
    ga_measurement_id: str = os.getenv("GA_MEASUREMENT_ID", "")
    ga_api_secret: str = os.getenv("GA_API_SECRET", "")


settings = Settings()
