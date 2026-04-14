from app.core.config import settings


def get_cors_options() -> dict:
    if settings.CORS_ALLOW_ALL_ORIGINS:
        return {
            "allow_origins": ["*"],
            "allow_origin_regex": None,
        }

    origins = [
        origin.strip()
        for origin in settings.CORS_ALLOWED_ORIGINS.split(",")
        if origin.strip()
    ]
    return {
        "allow_origins": origins,
        "allow_origin_regex": settings.CORS_ALLOWED_ORIGIN_REGEX or None,
    }
