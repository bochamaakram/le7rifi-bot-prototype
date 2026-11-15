# Deployment

## Supabase PostgreSQL

Use Supabase as the hosted database with the existing FastAPI backend. No Supabase client package or Flutter credentials are required. Select a direct connection or session pooler for this persistent backend and migrations; connection availability depends on IPv4/IPv6 support. See [Supabase connection guidance](https://supabase.com/docs/guides/database/connecting-to-postgres).

1. Use a dedicated development project. As its administrator, enable pgvector (`vector`) in the `public` schema before application migrations. Existing models use unqualified `vector` types, so an extension in another schema must be accessible through the application role's search path.
2. Create a dedicated login role with `NOSUPERUSER NOBYPASSRLS`, access to the database, and `USAGE, CREATE` on the schema used by the app. Use this same restricted role to own the migrated tables and run the API. Do not use the default `postgres` administration connection for application requests. See [Supabase role documentation](https://supabase.com/docs/guides/database/postgres/roles).
3. Set `SUPABASE_DATABASE_URL` (or `DATABASE_URL`) to that role's connection URI with its URL-encoded password and TLS enabled (`sslmode=require`, or certificate-verified TLS as provisioned). Preserve the dashboard host/port format and adapt its username for the dedicated role; session pooler usernames include the project reference. Keep application tables outside Data API exposure where possible, and do not grant access to `anon` or `authenticated`: the app's policies depend on backend transaction-local identity, not Supabase client claims.
4. From the backend directory run `alembic upgrade head`, then start Uvicorn as shown in the README. Configuration loads the root `.env` automatically and environment variables override dotenv values. Migrations only target this application's tables, all with forced RLS.
5. Check `/ready`, then validate isolation on a separate migrated test database with a restricted role and `TEST_DATABASE_URL`. Never use the live application project for automated isolation tests.

This configures storage only. Mobile login and SaaS identity remain as documented; Supabase Auth and production SaaS integration are pending. Hosted migrations, TLS connectivity and RLS have not been validated against a supplied Supabase project.

### Prepare the application role

In a dedicated development project's SQL editor, run the following as its database administrator. Replace the password placeholder locally with a unique random database password; do not commit it:

```sql
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
CREATE ROLE le7rayfi LOGIN PASSWORD 'REPLACE_WITH_RANDOM_DATABASE_PASSWORD'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT CONNECT ON DATABASE postgres TO le7rayfi;
GRANT USAGE, CREATE ON SCHEMA public TO le7rayfi;
```

This is one-time provisioning, not a script to rerun over an existing role. If pgvector is already installed in `extensions`, make it available to the role without relocating it:

```sql
GRANT USAGE ON SCHEMA extensions TO le7rayfi;
ALTER ROLE le7rayfi SET search_path = public, extensions;
```

Copy the session pooler host from **Connect** in the dashboard. Use `le7rayfi.PROJECT_REF` as the pooler username (direct connections use `le7rayfi`), URL-encode the password, and save the result only in `.env`:

```dotenv
SUPABASE_DATABASE_URL=postgresql://le7rayfi.PROJECT_REF:ENCODED_PASSWORD@DASHBOARD_SESSION_POOLER_HOST:5432/postgres?sslmode=require
```

Settings reject the built-in `postgres`/`supabase_admin` roles and missing TLS for `SUPABASE_DATABASE_URL`. The actual custom role must also have no inherited bypass privileges. Start with `sh scripts/run_backend.sh` from the repository root; it will not start Uvicorn if configuration or migrations fail. `DEV_TOKEN` must still contain at least 32 characters for development login. Open `.env` locally to copy it into the app; do not put provider keys or database credentials into the phone app.

## VPS with local PostgreSQL

Use one small VPS and Compose, one API worker, PostgreSQL persistent storage and Caddy. No GPU. Size the machine after measuring PDF ingestion and concurrent cloud requests; no capacity claim is established yet.

1. Install Docker Engine/Compose on the host. Copy source and `.env.example` to `.env` with restrictive file permissions. Generate independent random database/access credentials. URL-encode the app database password in `DATABASE_URL`.
2. Run `docker compose up --build -d`; confirm migrate exits 0, DB/api health checks pass and `/ready` reports actual configuration. The initial app role is created only on a fresh DB volume. Changing an env password does not change an existing database role: rotate it through an administrator and update `.env` together.
3. Before any production use set `ENVIRONMENT=production`, `AUTH_MODE=jwt`, trusted `JWT_ISSUER`, `JWT_AUDIENCE`, PEM `JWT_PUBLIC_KEY` (quoted multiline dotenv), and valid backend provider configuration. Startup refuses development auth in production. Real SaaS/PKCE is not available yet, so this step is infrastructure preparation, not a production release.
4. Point `API_DOMAIN` DNS at the VPS, expose ports 80/443 and start `docker compose --profile production up -d`. Caddy obtains TLS. Keep DB unexposed and API bound to host loopback. Firewall other inbound ports. Do not enable proxy access payload logging.
5. Build the Android client with your HTTPS `API_URL`; replace generated debug release signing with private release signing before distribution. Keep signing keys outside Git.

Migrations use the restricted table-owning app role; pgvector is installed by the initialization administrator. Forced RLS applies even to the table owner. Never run the API as the extension-installing superuser. Retain separate administration credentials for backups/maintenance. No connection pooler is required; transaction-local identity settings are essential if one is added.

Back up through the administration role (an app-scoped backup may omit RLS-protected rows):

```sh
mkdir -p backups
docker compose exec -T db pg_dump -U postgres -d le7rayfi -Fc > backups/le7rayfi.dump
```

Encrypt backups, restrict access and move them to independent storage. Define and test retention including deletion obligations. Test restore into an isolated database with `pg_restore`; never validate restoration over live data. Backup automation and a tested restore job are still pending. Bind the backups directory outside public serving and exclude it from Git.

Monitor `/health` for process liveness, `/ready` for DB schema access, JSON logs for status/latency, and authenticated `/api/v1/usage` for monthly quota consumption. None makes paid provider calls automatically. Provider availability needs an explicitly authorized smoke test. No secrets or end-user content should appear in logs.

Limits are in `.env` (models, timeouts, durations, units). LLM token usage/input recording duration are tracked; exact provider invoices, embedding/STT token accounting, output audio seconds and real currency caps are incomplete. Use provider-account spending controls. No expensive-model fallback exists. Rate limits are process-local: scaling past one worker requires shared state and a separate design.

Dependency ranges are declared for a prototype. Network restrictions prevented resolving complete lock files during initial implementation. Resolve dependencies, run all checks and produce reviewed pinned Python and Flutter dependency locks before deployment. Docker/Android builds and migration execution have not yet been validated here.
