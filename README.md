# Le7rayfi AI — الحريفي

Native Flutter Android client and FastAPI prototype for a voice-first Moroccan Darija business assistant. Backend keys stay on the server. The client records push-to-talk audio, lets the artisan edit the transcription, and sends confirmed text for a spoken/text response. SaaS data is explicitly **mock**; real SaaS OAuth integration is pending its contract.

**Implementation is underway, not release-ready.** See [validation and remaining work](docs/IMPLEMENTATION_STATUS.md). No live-provider or Android end-to-end result has been established.

## Requirements

- Python 3.12+ (Docker uses 3.12), ffmpeg/ffprobe.
- Docker with Compose, or PostgreSQL 17 with pgvector and a non-superuser application role.
- Stable Flutter with Dart 3.10+, Android SDK, Android device/emulator (API 23+).
- Internet for initial dependencies and your own AI provider key for real speech/chat.

## Local backend

```sh
cp .env.example .env
python -c 'import secrets; print(secrets.token_urlsafe(48))'
```

Set a separate random `DEV_TOKEN`, `POSTGRES_PASSWORD`, and `APP_DB_PASSWORD` in `.env`. Set `DATABASE_URL` with the URL-encoded application password (host `db` for Compose). Add your server-side `AI_API_KEY`. Without it AI endpoints return `503 provider_not_configured`; they never generate simulated answers. Defaults use OpenAI-compatible chat, transcription, speech and embeddings; endpoint/model compatibility must be checked if changing providers.

```sh
docker compose up --build -d
curl http://localhost:8000/health
curl http://localhost:8000/ready
```

Compose initializes a restricted role, waits for PostgreSQL, runs Alembic, then starts one API worker. API docs: `http://localhost:8000/docs`. Readiness checks the database and reports whether AI is configured; it makes no paid requests. Postgres has no host port by default.

For a separately provisioned local PostgreSQL database:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -e './backend[test]'
# Set DATABASE_URL in .env to the local DB host and restricted app role.
cd backend
# Backend loads the repository-root .env automatically.
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --no-access-log
```

Do not run application queries as the PostgreSQL superuser: that bypasses RLS. The database administrator installs pgvector before migrations; the application role owns its tables, with forced row policies.

## AgentRouter and Supabase

Backend configuration accepts these server-side variables in the root `.env`:

```dotenv
AGENTROUTER_API_KEY=your-agentrouter-key
AGENTROUTER_BASE_URL=https://agentrouter.org/v1
SUPABASE_DATABASE_URL=postgresql://restricted_role:URL_ENCODED_PASSWORD@YOUR_DB_HOST:5432/postgres?sslmode=require
```

When nonempty, `AGENTROUTER_API_KEY` selects `AGENTROUTER_BASE_URL` and takes precedence over the legacy `AI_API_KEY` / `AI_BASE_URL` pair. Set `LLM_MODEL`, `STT_MODEL`, `TTS_MODEL`, `TTS_VOICE` and `EMBEDDING_MODEL` to models supported by your account. All four adapters currently use the selected endpoint/key; chat availability alone does not establish audio or embedding support. Unsupported services return provider errors; no alternate paid provider is selected automatically. AgentRouter's [official docs](https://github.com/agentrouter-org/docs) describe its OpenAI-compatible interface; no live compatibility test has been run here.

Supabase is used as PostgreSQL storage through SQLAlchemy, with the existing pgvector schema and forced RLS. A nonempty `SUPABASE_DATABASE_URL` takes precedence over `DATABASE_URL`; either accepts `postgres://`, `postgresql://` or `postgresql+psycopg://`. Password encoding and query parameters are preserved. Supabase project URLs, publishable/anon keys and service-role API keys cannot replace the PostgreSQL connection string. These credentials belong only on the backend. Supabase Auth is not wired into the app by this configuration.

Follow the [Supabase deployment steps](docs/DEPLOYMENT.md#supabase-postgresql) before running migrations. For hosted storage, start the backend locally with the virtualenv commands above; the default Compose stack still starts its own local database.

After setting `SUPABASE_DATABASE_URL`, start from the repository root with:

```sh
sh scripts/run_backend.sh
```

This uses the project virtualenv, checks configuration and runs migrations before starting the API. It stops on migration failure. Supabase project URLs and publishable/secret API keys do not supply a database password or connection string. When those project settings exist but storage still targets localhost, the script reports the missing database configuration.

If startup reports a short `DEV_TOKEN`, generate a random token with `python -c 'import secrets; print(secrets.token_urlsafe(48))'` and save it as `DEV_TOKEN` in your local `.env`. Use that same token on the app's development login screen. Keep it private; Supabase storage does not change the current development login.

## Android client

```sh
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

Enter your backend `DEV_TOKEN` on the development login screen. This is an app access token, **not an AI provider key**. It is saved using Flutter secure storage. Development mode maps it to a single fixed demo identity. All demo profile data is labeled; this is not production login.

`10.0.2.2` reaches the host from the Android emulator. For a USB device use `adb reverse tcp:8000 tcp:8000` and `API_URL=http://127.0.0.1:8000`. HTTP cleartext is enabled only in the Android debug manifest. A release build requires an HTTPS API and your own release signing configuration.

Tap the microphone to start, tap again to stop (automatic stop after 60 seconds). Grant microphone permission. Review/edit the transcription and explicitly send. Text entry works independently. Speech playback can be switched off; a failed TTS call keeps the answer readable. History, business examples, preferences, deletion, export and quota usage are accessible from the chat toolbar.

## Generate an installable Android APK

From the repository root on a host with package downloads, a writable Flutter/Gradle cache and Android SDK:

```sh
./scripts/build_android.sh
adb install -r artifacts/le7rayfi-ai-debug.apk
```

The script resolves dependencies, runs analysis and tests, builds a debug APK, and copies it to `artifacts/le7rayfi-ai-debug.apk` only after success. For a USB-connected phone, run `adb reverse tcp:8000 tcp:8000` and build with `API_URL=http://127.0.0.1:8000 ./scripts/build_android.sh`. The backend must be running separately. This APK uses development signing and is intended for testing.

## Validation

```sh
. .venv/bin/activate
(cd backend && pytest)
(cd mobile && flutter analyze && flutter test)
python -m unittest discover -s evaluation -p test_evaluate.py -v
```

Paid APIs are mocked in automated tests. PostgreSQL isolation tests skip unless `TEST_DATABASE_URL` points at a **dedicated migrated test database**, using a restricted role; never point them at production. They deliberately query without tenant filters to verify database RLS. To run migrations for this test DB, set `DATABASE_URL` to that URL before `alembic upgrade head`.

For explicit real-provider validation (incurs your provider's charges):

```sh
export SMOKE_ACCESS_TOKEN='your-development-access-token'
python scripts/provider_smoke.py --allow-paid --audio /path/to/darija.wav
```

The smoke script requires review of the transcription, then saves generated MP3 to `/tmp`. Never commit recordings or personal customer information. See [speech evaluation](docs/DARija_EVALUATION.md); no provider has been ranked for Darija.

## Project notes

For o2switch shared hosting, use the [cPanel deployment guide](docs/O2SWITCH.md).
Create the source-only upload zip with `.venv/bin/python scripts/package_o2switch.py`.

[Architecture](docs/ARCHITECTURE.md) · [API](docs/API_CONTRACT.md) · [SaaS integration](docs/SAAS_INTEGRATION.md) · [Security/privacy](docs/SECURITY.md) · [Deployment](docs/DEPLOYMENT.md) · [Status](docs/IMPLEMENTATION_STATUS.md)
