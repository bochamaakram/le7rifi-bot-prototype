# o2switch shared hosting deployment

This path targets cPanel **Setup Python App**, using Python 3.12+ and Passenger.
FastAPI remains the API; `a2wsgi` adapts HTTP requests to WSGI. Supabase remains
PostgreSQL storage and AgentRouter remains the AI gateway. WebSockets are not
supported through this entry point (the current app uses REST).

References: [o2switch Python setup](https://faq.o2switch.fr/cpanel/logiciels/hebergement-python-multi-version/),
[o2switch SSH](https://faq.o2switch.fr/guides/webmastering/connexion-ssh/),
[a2wsgi ASGI adapter](https://github.com/abersheeran/a2wsgi#asgimiddleware).

## 1. Prepare the source and tester login locally

Choose your real API subdomain before running the credential command:

```sh
.venv/bin/python scripts/create_hosted_tester.py --issuer https://api.YOUR_DOMAIN
.venv/bin/python scripts/package_o2switch.py
```

The zip is `artifacts/le7rayfi-o2switch.zip`. It contains backend source,
migrations, packaging metadata and these instructions. It excludes `.env`,
credentials, recordings, mobile builds and local virtualenvs.

The credentials command creates `artifacts/hosted-auth/` with owner-only permissions.
Keep `private.pem` on your local computer. The token in `tester-token.txt` is a
7-day credential for the existing demo artisan/tenant, for private pilot testing.
It uses the backend's existing RS256 validator and is not a SaaS OAuth integration.
The app's token-entry screen accepts it without a mobile auth change. To rotate
keys, choose a new output directory and replace the server public key; this revokes
tokens signed by the previous key. There is no individual token revocation flow.

## 2. Create the Python application

In cPanel, create your API subdomain and enable its HTTPS certificate. Then create
an application under **Setup Python App**:

| Field | Value |
| --- | --- |
| Python version | 3.12 or newer |
| Application root | `le7rayfi/backend` |
| Application URL | Your API subdomain, mounted at `/` |
| Startup file | `passenger_wsgi.py` |
| Entry point | `application` |
| Passenger log | A private path outside the domain document root |

Upload/extract the zip into `/home/CPANEL_USER/le7rayfi/`, preserving the
`backend/` directory. Keep this directory separate from the domain document root
and `public_html`. cPanel manages the domain's Passenger `.htaccess` mapping.
Do not upload the local `.venv` or any signing private key.

## 3. Configure private settings

Create `/home/CPANEL_USER/le7rayfi/.env` with file permissions `600`, outside the
public document root. Copy the contents of local `artifacts/hosted-auth/backend.env`
into it (including the complete quoted multiline public key), then add:

```dotenv
SUPABASE_DATABASE_URL=postgresql://le7rayfi.PROJECT_REF:ENCODED_APP_ROLE_PASSWORD@YOUR_SESSION_POOLER:5432/postgres?sslmode=require
AGENTROUTER_API_KEY=YOUR_SERVER_SIDE_KEY
AGENTROUTER_BASE_URL=https://agentrouter.org/v1
LLM_MODEL=YOUR_AVAILABLE_CHAT_MODEL
STT_MODEL=YOUR_AVAILABLE_TRANSCRIPTION_MODEL
TTS_MODEL=YOUR_AVAILABLE_SPEECH_MODEL
TTS_VOICE=YOUR_AVAILABLE_VOICE
EMBEDDING_MODEL=YOUR_AVAILABLE_EMBEDDING_MODEL
EMBEDDING_DIMENSIONS=1536
```

Use the working Supabase URI from the local `.env`, preserving its restricted
role, encoded password, project-qualified pooler username and TLS. Provider
model names must be confirmed in your account; this deployment does not change
models, top up balance, or validate speech/embedding support. Never put provider
keys or DB credentials into Flutter. cPanel environment variables override dotenv;
remove conflicting values in its application settings.

Passenger requires `ENVIRONMENT=production` and `AUTH_MODE=jwt` and refuses
development authentication. Do not upload the local development `.env` unchanged.

## 4. Install and check the server

In cPanel Terminal/SSH, run the virtualenv activation command displayed by
**Setup Python App** (its exact path belongs to your account), then:

```sh
cd ~/le7rayfi/backend
python --version
python -m pip install '.[o2switch]'
command -v ffmpeg
command -v ffprobe
python -m alembic upgrade head
```

The voice upload validator requires **both ffmpeg and ffprobe**. If either is
missing, ask o2switch which supported installation/path is available for your
account; add its directory to the application's PATH. Do not bypass validation.
Their availability on your account has not been established.

Supabase's session pooler requires outbound TCP 5432, and AgentRouter requires
HTTPS 443. If database connectivity is blocked, ask o2switch about outbound
firewall access for your pooler. Avoid printing connection strings, settings
objects or raw exception tracebacks containing sensitive upstream data.

Only restart the Python application after dependencies, settings and migrations
succeed. Use cPanel **Restart**; do not run `run_backend.sh`, Docker, or a
background Uvicorn command for this Passenger deployment. Migrations are a
separate operator step, never triggered by HTTP requests.

Passenger's WSGI interface does not dispatch FastAPI lifespan. The adapter
explicitly validates settings before serving and disposes an existing DB engine
at process exit, mirroring the current lifespan. Update both if startup changes.

## 5. Verify and connect Android

```sh
curl --fail https://api.YOUR_DOMAIN/health
curl --fail https://api.YOUR_DOMAIN/ready
```

Neither endpoint sends paid AI requests. `/ready` checks the database schema and
whether a provider key is configured, not provider balance or model availability.
Also open `/api/v1/me` without credentials: it must return 401. Configure hosting
logs to avoid request bodies and Authorization headers. Check request duration
limits with the host for slow STT/LLM/TTS calls; account-specific timeouts and
upload limits have not been verified.

For Android, rebuild with the actual HTTPS address:

```sh
cd mobile
flutter build apk --release --dart-define=API_URL=https://api.YOUR_DOMAIN
```

Install the resulting APK and paste the private contents of `tester-token.txt`
on the current login screen. USB forwarding is no longer needed. The existing
release build uses development signing and remains for pilot testing only.

The rate limiter is process-local. Ask the host to limit this application to
one Passenger process; do not claim a shared rate limit across multiple
processes. Database quotas still use the shared ledger. Public multi-user release
requires real identity integration and the other hardening work in the status
document. Do not run destructive isolation tests against the hosted app project;
use a separate `TEST_DATABASE_URL` for those tests.

No o2switch upload or hosted runtime verification has been performed by preparing
this package. Server credentials/access, API domain, TLS, network access, audio
binaries and runtime checks are still needed on the actual account.
