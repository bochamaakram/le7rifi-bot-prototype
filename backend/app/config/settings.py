from functools import lru_cache
from pathlib import Path
from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(Path(__file__).resolve().parents[3] / ".env", ".env"), extra="ignore",
        hide_input_in_errors=True,
    )
    environment: str = "development"
    database_url: str = Field(default="postgresql+psycopg://le7rayfi:local-only@localhost:5432/le7rayfi", repr=False)
    supabase_database_url: str = Field(default="", repr=False)
    auth_mode: str = "dev"
    dev_token: str = Field(default="", repr=False)
    jwt_issuer: str = ""
    jwt_audience: str = ""
    jwt_public_key: str = ""
    saas_mode: str = "mock"
    ai_base_url: str = "https://api.openai.com/v1"
    ai_api_key: str = Field(default="", repr=False)
    agentrouter_api_key: str = Field(default="", repr=False)
    agentrouter_base_url: str = "https://agentrouter.org/v1"
    llm_model: str = "gpt-4o-mini"
    stt_model: str = "gpt-4o-mini-transcribe"
    tts_model: str = "gpt-4o-mini-tts"
    tts_voice: str = "coral"
    embedding_model: str = "text-embedding-3-small"
    embedding_dimensions: int = 1536
    provider_timeout_seconds: float = 45
    max_audio_seconds: int = 60
    max_audio_bytes: int = 4_000_000
    max_document_bytes: int = 2_000_000
    max_document_chunks: int = 100
    max_output_tokens: int = 600
    max_requests_per_minute: int = 20
    monthly_units_per_user: int = 500
    monthly_units_per_tenant: int = 5000
    retention_days: int = 30

    @property
    def provider_api_key(self) -> str:
        return self.agentrouter_api_key or self.ai_api_key

    @property
    def provider_base_url(self) -> str:
        return self.agentrouter_base_url if self.agentrouter_api_key else self.ai_base_url

    @model_validator(mode="after")
    def validate_modes(self):
        # Supabase supplies standard PostgreSQL URIs; this application uses psycopg 3.
        self.database_url = self.supabase_database_url or self.database_url
        for prefix in ("postgres://", "postgresql://"):
            if self.database_url.startswith(prefix):
                self.database_url = "postgresql+psycopg://" + self.database_url[len(prefix):]
                break
        if self.supabase_database_url:
            try:
                uri = make_url(self.database_url)
            except Exception:
                raise ValueError("SUPABASE_DATABASE_URL must be a PostgreSQL connection URI") from None
            if uri.drivername != "postgresql+psycopg" or not all((uri.host, uri.username, uri.password, uri.database)):
                raise ValueError("SUPABASE_DATABASE_URL must include PostgreSQL host, role, password and database")
            if uri.username.split(".", 1)[0] in {"postgres", "supabase_admin"}:
                raise ValueError("SUPABASE_DATABASE_URL requires a dedicated NOSUPERUSER NOBYPASSRLS role")
            if uri.query.get("sslmode") not in {"require", "verify-ca", "verify-full"}:
                raise ValueError("SUPABASE_DATABASE_URL requires sslmode=require or certificate-verified TLS")
        if self.auth_mode not in {"dev", "jwt"}:
            raise ValueError("auth_mode must be dev or jwt")
        if self.saas_mode != "mock":
            raise ValueError("Real SaaS contract is not configured; only labeled mock mode is available")
        if self.environment != "development" and self.auth_mode == "dev":
            raise ValueError("Development authentication is forbidden outside development")
        if self.auth_mode == "dev" and len(self.dev_token) < 32:
            raise ValueError("Set a random DEV_TOKEN of at least 32 characters")
        if self.auth_mode == "jwt" and not all((self.jwt_public_key, self.jwt_issuer, self.jwt_audience)):
            raise ValueError("JWT issuer, audience and public key required")
        if not 1 <= self.max_audio_seconds <= 120:
            raise ValueError("max_audio_seconds must be 1..120")
        if self.embedding_dimensions != 1536:
            raise ValueError("Schema currently requires 1536-dimensional embeddings")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
