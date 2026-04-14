from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+psycopg://postgres:postgres@localhost:5432/school_erp"
    JWT_SECRET: str = "CHANGE_ME"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60
    API_HOST: str = "127.0.0.1"
    API_PORT: int = 8000
    CORS_ALLOW_ALL_ORIGINS: bool = False
    CORS_ALLOWED_ORIGINS: str = "http://localhost,http://127.0.0.1"
    CORS_ALLOWED_ORIGIN_REGEX: str = r"https?://(localhost|127\.0\.0\.1)(:\d+)?$"

settings = Settings()
