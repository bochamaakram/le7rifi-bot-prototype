"""HTTP-only Passenger entry point; cPanel serves TLS and manages processes."""
import atexit

from a2wsgi import ASGIMiddleware

from app.config.settings import get_settings
from app.main import app
from app.models.database import engine


def create_application():
    # WSGI does not dispatch ASGI lifespan events. Mirror the current lifespan's
    # validation/disposal explicitly; keep this aligned if lifespan changes.
    settings = get_settings()
    if settings.environment != "production" or settings.auth_mode != "jwt":
        raise RuntimeError("Passenger hosting requires ENVIRONMENT=production and AUTH_MODE=jwt")

    def dispose_database():
        # Do not create a new engine just to clean up a process that never used it.
        if engine.cache_info().currsize:
            engine().dispose()

    atexit.register(dispose_database)
    return ASGIMiddleware(app, wait_time=5.0)
