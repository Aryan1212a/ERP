from pathlib import Path
from urllib.parse import urlsplit

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_NAME: str = "School ERP"
    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    DATABASE_URL: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60
    API_HOST: str = "127.0.0.1"
    API_PORT: int = 8000
    INIT_DB_ON_STARTUP: bool = True
    CORS_ALLOW_ALL_ORIGINS: bool = False
    CORS_ALLOWED_ORIGINS: str = "http://localhost,http://127.0.0.1"
    CORS_ALLOWED_ORIGIN_REGEX: str = r"https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    @model_validator(mode="after")
    def validate_safe_configuration(self) -> "Settings":
        jwt_secret = self.JWT_SECRET.strip()
        placeholder_secrets = {"CHANGE_ME", "replace-with-a-long-random-secret"}
        if not jwt_secret or jwt_secret in placeholder_secrets:
            raise ValueError("JWT_SECRET must be configured with a non-placeholder value")

        database_url = self.DATABASE_URL.lower()
        if self.APP_ENV.lower() == "production":
            if database_url.startswith("sqlite"):
                raise ValueError("Production DATABASE_URL must not use SQLite")
            if not database_url.startswith(("postgresql://", "postgresql+")):
                raise ValueError("Production DATABASE_URL must use PostgreSQL")
            if self.INIT_DB_ON_STARTUP:
                raise ValueError("INIT_DB_ON_STARTUP must be false in production")

        return self


def describe_database_url(database_url: str) -> str:
    parsed = urlsplit(database_url)
    database = parsed.path.rsplit("/", 1)[-1] if parsed.path else "configured"
    return f"driver={parsed.scheme or 'configured'}, host={parsed.hostname or 'local'}, database={database or 'configured'}"


settings = Settings()
