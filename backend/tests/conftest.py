import os

# Never inherit developer database/provider credentials from dotenv or the shell.
# TEST_DATABASE_URL is intentionally separate and only used by opt-in DB tests.
os.environ.update({
    'DEV_TOKEN': 'test-only-token-with-at-least-32-characters',
    'AUTH_MODE': 'dev',
    'ENVIRONMENT': 'development',
    'SAAS_MODE': 'mock',
    'DATABASE_URL': 'postgresql+psycopg://test:test@localhost:5432/test',
    'SUPABASE_DATABASE_URL': '',
    'AI_API_KEY': '',
    'AGENTROUTER_API_KEY': '',
    'AI_BASE_URL': 'https://provider.invalid/v1',
    'AGENTROUTER_BASE_URL': 'https://agentrouter.org/v1',
})
