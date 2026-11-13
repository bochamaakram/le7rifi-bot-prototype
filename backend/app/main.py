import json
import logging
import time
from contextlib import asynccontextmanager
from uuid import uuid4
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from sqlalchemy import text
from app.api.routes import router
from app.config.settings import get_settings
from app.models.database import engine

logger = logging.getLogger("le7rayfi")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app):
    get_settings()
    yield
    engine().dispose()


app = FastAPI(title="Le7rayfi AI", version="0.1.0", lifespan=lifespan)
app.include_router(router)


@app.exception_handler(HTTPException)
async def api_error(request, error):
    return JSONResponse({"error": error.detail}, status_code=error.status_code, headers=error.headers)


@app.middleware("http")
async def request_metadata(request: Request, call_next):
    start, request_id = time.monotonic(), str(uuid4())
    try:
        response = await call_next(request)
    except Exception:
        # No exception strings: SQL/provider messages may contain private data.
        response = JSONResponse({"error": "internal_error"}, status_code=500)
    response.headers.update({"X-Request-ID": request_id, "Cache-Control": "no-store",
                             "X-Content-Type-Options": "nosniff"})
    route = request.scope.get("route")
    logger.info(json.dumps({"request_id": request_id, "method": request.method,
        "route": getattr(route, "path", "unmatched"), "status": response.status_code,
        "duration_ms": round((time.monotonic() - start) * 1000)}))
    return response


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    try:
        with engine().connect() as connection:
            connection.execute(text("SELECT 1 FROM conversations LIMIT 0"))
        return {"status": "ready", "saas_mode": get_settings().saas_mode,
                "ai_configured": bool(get_settings().ai_api_key)}
    except Exception:
        return JSONResponse({"error": "database_unavailable"}, status_code=503)

from app.security.body_limit import BodyLimitMiddleware
app.add_middleware(BodyLimitMiddleware)


@app.exception_handler(RequestValidationError)
async def validation_error(request, error):
    return JSONResponse({"error": "validation_error", "fields": [
        {"location": list(item["loc"]), "type": item["type"]} for item in error.errors()]}, status_code=422)
