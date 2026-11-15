"""Configuration and HTTP transport tests; never contact a real provider or DB."""
import httpx
import pytest

from app.ai.providers.openai import OpenAIProvider, ProviderError
from app.config.settings import Settings


def settings(**overrides):
    values = {"ai_api_key": "", "agentrouter_api_key": "", "supabase_database_url": ""}
    values.update(overrides)
    return Settings(_env_file=None, dev_token="test-only-" * 4, **values)


def test_agentrouter_key_selects_its_own_endpoint():
    config = settings(agentrouter_api_key="router-test", ai_api_key="legacy-test")
    assert config.provider_api_key == "router-test"
    assert config.provider_base_url == "https://agentrouter.org/v1"
    custom = settings(agentrouter_api_key="router-test", agentrouter_base_url="https://router.invalid/v1")
    assert custom.provider_base_url == "https://router.invalid/v1"
    legacy = settings(ai_api_key="legacy-test", ai_base_url="https://legacy.invalid/v1")
    assert legacy.provider_api_key == "legacy-test"
    assert legacy.provider_base_url == "https://legacy.invalid/v1"


@pytest.mark.parametrize("scheme", ["postgres", "postgresql", "postgresql+psycopg"])
def test_supabase_uri_preserves_credentials_and_tls(scheme):
    uri = f"{scheme}://restricted:p%40ss@db.example.invalid:5432/postgres?sslmode=require"
    config = settings(supabase_database_url=uri)
    assert config.database_url == uri.replace(f"{scheme}://", "postgresql+psycopg://", 1)
    assert settings(database_url=uri).database_url == config.database_url
    assert "p%40ss" not in repr(config)


def test_secrets_are_hidden_in_settings_repr():
    config = settings(agentrouter_api_key="router-secret", ai_api_key="legacy-secret")
    assert "router-secret" not in repr(config)
    assert "legacy-secret" not in repr(config)
    assert config.dev_token not in repr(config)


@pytest.mark.parametrize('uri', [
    'https://project.supabase.co',
    'postgresql://postgres:secret@db.invalid:5432/postgres?sslmode=require',
    'postgresql://postgres.project:secret@pooler.invalid:5432/postgres?sslmode=require',
    'postgresql://restricted:secret@db.invalid:5432/postgres',
    'postgresql://restricted:secret@db.invalid:5432/postgres?sslmode=disable',
])
def test_supabase_rejects_api_urls_admin_roles_and_plaintext(uri):
    with pytest.raises(ValueError):
        settings(supabase_database_url=uri)


def test_settings_validation_does_not_display_secrets():
    from pydantic import ValidationError
    secret = 'must-never-appear-in-startup-errors'
    with pytest.raises(ValidationError) as error:
        settings(supabase_database_url=secret)
    assert secret not in str(error.value)


def test_supabase_session_pooler_custom_role():
    config = settings(supabase_database_url=(
        'postgresql://le7rayfi.project:p%40ss@pooler.invalid:5432/postgres?sslmode=require'))
    assert config.database_url.startswith('postgresql+psycopg://le7rayfi.project:')


def test_dotenv_loads_without_shell_export(tmp_path, monkeypatch):
    # Use a temporary dotenv rather than the developer's credentials.
    env = tmp_path / ".env"
    env.write_text("AGENTROUTER_API_KEY=dotenv-test\nDEV_TOKEN=" + "x" * 40 + "\n")
    monkeypatch.delenv("AGENTROUTER_API_KEY", raising=False)
    monkeypatch.chdir(tmp_path)
    config = Settings(_env_file=env)
    assert config.provider_api_key == "dotenv-test"


@pytest.mark.asyncio
async def test_agentrouter_transport_and_safe_errors(monkeypatch):
    seen = []

    def handle(request):
        seen.append(request)
        return httpx.Response(401, json={"error": "sensitive-upstream-body"})

    client_class = httpx.AsyncClient
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: client_class(
        transport=httpx.MockTransport(handle), **kwargs))
    provider = OpenAIProvider(settings(agentrouter_api_key="test-router-key"))
    with pytest.raises(ProviderError, match="^provider_unavailable$"):
        await provider.request("/chat/completions", json={"model": "test"})
    assert len(seen) == 1
    assert str(seen[0].url) == "https://agentrouter.org/v1/chat/completions"
    assert seen[0].headers["Authorization"] == "Bearer test-router-key"


@pytest.mark.asyncio
async def test_missing_key_does_not_open_http_client(monkeypatch):
    def unexpected(**kwargs):
        pytest.fail("Unconfigured provider attempted HTTP")
    monkeypatch.setattr(httpx, "AsyncClient", unexpected)
    with pytest.raises(ProviderError, match="provider_not_configured"):
        await OpenAIProvider(settings()).request("/chat/completions")
