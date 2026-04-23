import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.api import api_router
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.core.logging import setup_logging
from app.core.network import get_cors_options
from app.db.session import Base, engine

setup_logging(settings.LOG_LEVEL)
logger = logging.getLogger(__name__)

app = FastAPI(title=settings.APP_NAME)
cors_options = get_cors_options()

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_options["allow_origins"],
    allow_origin_regex=cors_options["allow_origin_regex"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")
register_exception_handlers(app)

@app.on_event("startup")
def on_startup() -> None:
    if settings.INIT_DB_ON_STARTUP:
        Base.metadata.create_all(bind=engine)
        logger.info("Database schema ensured from SQLAlchemy models")
    logger.info("Application started in %s mode", settings.APP_ENV)
