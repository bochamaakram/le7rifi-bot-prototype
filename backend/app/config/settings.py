from functools import lru_cache
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    environment: str = "development"
    database_url: str = "postgresql+psycopg://le7rayfi:local-only@localhost:5432/le7rayfi"
    auth_mode: str = "dev"
    dev_token: str = ""
    jwt_issuer: str = ""
    jwt_audience: str = ""
    jwt_public_key: str = ""
    saas_mode: str = "mock"
    ai_base_url: str = "https://api.openai.com/v1"
    ai_api_key: str = ""
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

    @model_validator(mode="after")
    def validate_modes(self):
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
