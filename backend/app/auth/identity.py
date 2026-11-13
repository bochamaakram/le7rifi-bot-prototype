import secrets
from dataclasses import dataclass
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.config.settings import Settings, get_settings


@dataclass(frozen=True)
class Identity:
    tenant_id: str
    user_id: str
    token: str


bearer = HTTPBearer(auto_error=False)


def authenticate(credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
                 settings: Settings = Depends(get_settings)) -> Identity:
    if credentials is None:
        raise HTTPException(401, "authentication_required")
    token = credentials.credentials
    if settings.auth_mode == "dev":
        if secrets.compare_digest(token, settings.dev_token):
            return Identity("demo-tenant", "demo-artisan", token)
        raise HTTPException(401, "invalid_token")
    try:
        claims = jwt.decode(token, settings.jwt_public_key, algorithms=["RS256"],
                            audience=settings.jwt_audience, issuer=settings.jwt_issuer,
                            options={"require": ["exp", "iat", "sub", "tenant_id"]})
        tenant, user = claims["tenant_id"], claims["sub"]
        if not isinstance(tenant, str) or not isinstance(user, str) or not tenant or not user:
            raise ValueError("Invalid identity")
        return Identity(tenant, user, token)
    except (jwt.PyJWTError, ValueError):
        raise HTTPException(401, "invalid_token") from None
