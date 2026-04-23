from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_NAME: str = "School ERP"
    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    DATABASE_URL: str = "postgresql+psycopg://postgres:postgres@localhost:5432/school_erp"
    JWT_SECRET: str = "CHANGE_ME"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60
    API_HOST: str = "127.0.0.1"
    API_PORT: int = 8000
    INIT_DB_ON_STARTUP: bool = True
    CORS_ALLOW_ALL_ORIGINS: bool = False
    CORS_ALLOWED_ORIGINS: str = "http://localhost,http://127.0.0.1"
    CORS_ALLOWED_ORIGIN_REGEX: str = r"https?://(localhost|127\.0\.0\.1)(:\d+)?$"

settings = Settings()
