# Deployment

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
