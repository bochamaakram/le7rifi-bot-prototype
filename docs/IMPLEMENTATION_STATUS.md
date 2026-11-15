# Implementation status

## o2switch shared-hosting preparation — 2026-11-15

- Prepared for the documented cPanel Setup Python App / Passenger WSGI path, assuming shared hosting until the account type is confirmed. Added optional `o2switch` dependency extra (`a2wsgi`), `backend/passenger_wsgi.py` and `app/passenger.py`. The HTTP adapter explicitly validates production JWT configuration before serving and disposes an existing DB engine on exit because WSGI does not dispatch ASGI lifespan. Development login is refused by this entry point. WebSockets are unsupported; current endpoints use REST.
- Added local `scripts/create_hosted_tester.py` to generate an RSA key pair and a 7-day demo-identity JWT compatible with the existing phone token-entry screen. Generated artifacts are private, never overwritten and not included in the upload zip. This is a pilot login tool, not real SaaS identity/OAuth integration. No real signing keys were generated during preparation because the API domain is not supplied.
- Added `scripts/package_o2switch.py` and generated `artifacts/le7rayfi-o2switch.zip` with allowlisted backend sources, migrations and hosting instructions. Local dotenv, private keys, audio, tests, caches, mobile builds and virtualenvs are excluded. Added `docs/O2SWITCH.md`, linked from README and deployment docs, with cPanel fields, private settings, dependency/migration commands, HTTPS checks, ffmpeg/ffprobe requirements, pooler networking, process-local limiter limitations and Android rebuild instructions.
- Validation: **33 backend tests passed, 1 PostgreSQL isolation test skipped, 7 subtests passed**; **6 Flutter tests passed**. New checks exercise real WSGI health/auth rejection/upload limits, refuse development hosting, verify generated JWTs with the existing validator and verify packaging excludes credentials. Flutter analysis still exits 1 with **21 existing informational findings**. Python compile and diff whitespace checks passed. Installed a2wsgi 1.10.10 for local validation; tests used no paid provider requests.
- Not deployed: no o2switch account access or API domain supplied. Remote Python version, ffmpeg/ffprobe, outbound 5432/443, Passenger process count/timeouts, HTTPS and actual hosted execution need account validation. A separate `TEST_DATABASE_URL` is still missing; no destructive isolation tests ran on the app's Supabase project. Provider balance/model compatibility and native-speaker Darija quality remain outside these checks.

## Supabase session pooler connected — 2026-11-15

- Updated ignored local `.env` to the user-supplied session-pooler host on port 5432, with `le7rayfi.PROJECT_REF` username and TLS. Preserved the saved password without printing it. This replaces the direct host that failed on the user's IPv6-unreachable network and corrects the administrative username rejected by settings.
- Live connection succeeded outside sandbox network restrictions. PostgreSQL confirmed the connected role is neither superuser nor `BYPASSRLS`.
- Applied Alembic migrations successfully to the configured project: revision **0001**. Read-only catalog checks confirmed every application model's table has both enabled and forced RLS.
- These are live connection/migration/catalog checks, not the dedicated PostgreSQL isolation suite. That suite remains pending a separate `TEST_DATABASE_URL`; it was not pointed at this application project. No paid AI calls or device tests were performed. No application code changed, so the previously recorded automated test results remain unchanged.

## Supabase startup configuration — 2026-11-15

- Replaced the local four-character development token with a random token in ignored `.env`; no token value was printed. Local file permissions restricted to its owner. Development login still uses this token; Supabase Auth is not integrated.
- Supabase database configuration now validates PostgreSQL URI fields, requires TLS, rejects built-in administrative usernames, and hides configuration inputs from validation tracebacks. Actual role privileges still require database verification.
- Added `scripts/run_backend.sh`: uses the project virtualenv, checks settings, reports API-key/local-database mismatch, applies migrations, and starts Uvicorn only on success. README and deployment docs include restricted-role SQL and session-pooler URI instructions.
- Isolated backend automated tests from local database/provider credentials. Backend pytest: **29 passed, 1 skipped, 7 subtests passed**. PostgreSQL isolation skipped because no dedicated `TEST_DATABASE_URL` was available. Flutter tests: **6 passed**. Flutter analysis: exit 1 with **21 existing informational lint findings**. Shell syntax and diff whitespace checks passed. Tests needed execution outside sandbox restrictions; no paid provider calls were made.
- Local saved `SUPABASE_DATABASE_URL` initially contained an API/project URL. After the user supplied a direct PostgreSQL host, saved that host with TLS, the dedicated `le7rayfi` role and an explicit password placeholder in ignored `.env`. The user must provision this role using the documented SQL and replace the placeholder with that role's password. URI fields were checked locally; no Supabase connection or hosted migration has been executed. Direct-host network reachability remains unverified.

## AgentRouter / Supabase configuration — 2026-11-13

- Added `AGENTROUTER_API_KEY` and `AGENTROUTER_BASE_URL` (default `https://agentrouter.org/v1`). A nonempty AgentRouter key selects its own endpoint and overrides legacy AI configuration. Readiness checks the selected key.
- Added `SUPABASE_DATABASE_URL` override and normalization of standard PostgreSQL URIs to psycopg 3, preserving encoded passwords and TLS options. Existing SQLAlchemy/pgvector storage, identity scoping and forced RLS remain in use. Supabase REST keys and Supabase Auth are not integrated.
- Root `.env` now loads when starting from `backend/`; process environment overrides dotenv. Database URLs, AI keys and dev tokens are excluded from settings repr. No secrets were displayed or modified. The existing `.env.example` deletion was preserved.
- README and deployment documentation cover hosted database setup with a restricted role, pgvector and model compatibility limitations. All four AI adapters share the selected gateway; AgentRouter audio/embedding and model support remain unverified.
- Eight new configuration/HTTP transport tests use mocked HTTP and cover endpoint/key precedence, URI normalization, secret repr, dotenv loading and safe errors.
- Backend dependencies installed with network access. Full pytest outside the sandbox: **22 passed, 1 skipped, 7 subtests passed**. PostgreSQL isolation skipped: no dedicated `TEST_DATABASE_URL`. Initial sandbox HTTP tests stalled. Python compileall and diff whitespace checks passed.
- Flutter tests: **6 passed**. Analysis returned exit 1 with **21 existing informational lint findings** concerning braces and async BuildContext use. Validation required access to the shared SDK cache outside the sandbox. Mobile source was not changed.
- The inspected workspace `.env` lacked `AGENTROUTER_API_KEY` and `SUPABASE_DATABASE_URL`; its database URL targeted a local host. No hosted migrations, live database/provider calls or speech evaluation were performed. No paid provider requests were made.

The earlier history below records the initial environment; dependency installation and Flutter testing are now available as reported above. Live database, Android device and Darija evaluation work remains outstanding.

Updated 2026-11-13. This is the first implementation increment. **The end-to-end voice milestone is implemented in source but not yet validated and is not marked complete.** No production or speech-quality claim is made.

## Phase 0 — inspection and setup

Repository originally contained only the master prompt. Native Flutter SDK (3.47.3 / Dart 3.13.3), Python 3.14.8 and ffmpeg/ffprobe are installed. Docker CLI exists but daemon access is denied. The shared Flutter SDK/pub cache are read-only; writable copies under `/tmp` allowed project generation and partial validation. Workspace `.git` is not an initialized writable repository, so no commit was made.

Created architecture/plan, API and proposed SaaS contract, security/privacy, deployment and evaluation documentation, AGENTS.md, environment template and run instructions. Monorepo uses the existing root rather than a redundant nested directory.

## Implemented in source

- Native Flutter Android scaffolding, Riverpod chat state, Dio authenticated client, GoRouter navigation, Arabic/RTL app chrome, system light/dark themes and accessible microphone/text controls.
- Development login with secure access-token storage, startup session check and explicit mock-data notices; real OAuth flow pending.
- WAV push-to-talk, 60-second auto stop, cancel, bounded upload, editable transcription preview before submission, text fallback, loading/error/retry states, optional MP3 playback and ephemeral client files.
- History/list/load/delete, business context screen, preference approval/disable/delete, script choice, conversation/document export display/copy, usage and logout screens.
- FastAPI versioned endpoints, strict schemas, structured answers, provider interfaces and concrete configurable OpenAI-compatible chat/STT/TTS/embedding calls. Missing provider credentials return an explicit error. TTS failure preserves text. No automatic retries/fallback models.
- Fixed server-side development identity and RS256 JWT validator for a future compatible SaaS issuer. Client-supplied identity fields rejected; startup configuration guards.
- Typed read-only SaaS interface, clearly labeled mock profile, fail-fast real-adapter boundary and personalization prompt assembly.
- SQLAlchemy PostgreSQL/pgvector models, initial Alembic migration, forced tenant/user RLS, transaction-local identity, private vector retrieval, conversation persistence, preference controls and lazy conversation retention.
- Private PDF/TXT/Markdown extraction, chunking/embeddings, upload/list/delete APIs. Approved global articles and website ingestion pending.
- Input and streamed-body limits, actual audio probing/decoding/duration/silence checks, provider timeouts, safe errors, metadata logs, single-process rate limits, advisory-lock quota admission, user usage ledger and separate tenant/month counters.
- Dockerfiles/Compose with restricted DB role, persistent volumes, migration dependency, health checks and optional Caddy HTTPS profile. Backup/restore instructions.
- Framework/API/provider/JWT/isolation/quota tests, Flutter API/controller/widget/voice tests, standalone domain checks, optional explicitly billable smoke script, Darija metric harness and manual native-speaker rating format.

Main files: `backend/app/` (API, identity, providers, orchestration, SaaS, models, validation, limits), `backend/migrations/`, `backend/tests/`, `mobile/lib/`, `mobile/test/`, `evaluation/`, `scripts/`, `infra/`, `docker-compose.yml`, `.env.example`, and `docs/`. No real credentials or recordings included.

## Executed validation

| Check | Actual result |
|---|---|
| Native Android project generation with cached Flutter | Passed; Android platform files created |
| Python compileall across backend/evaluation/scripts | Passed |
| Audio/chunk domain unittest suite | 5 tests passed using actual ffprobe/ffmpeg |
| Streamed body middleware unittest suite | 2 tests passed |
| Evaluation metrics unittest suite | 2 tests passed; synthetic unit fixtures only, not provider benchmarks |
| Standalone Dart voice-state smoke | 4 checks passed |
| Dart formatting/parsing of app and test source | Passed |
| Android manifest XML and Compose/pubspec YAML parsing | Passed |
| Dart analyzer on `app_theme.dart` | Passed, no issues |
| Python dependency installation | Blocked: PyPI DNS/network unavailable; FastAPI, Pydantic, PyJWT, Alembic, pgvector and pytest unavailable |
| Full backend pytest | Could not run: pytest/framework dependencies missing |
| Flutter dependency resolution | Blocked: Dio/GoRouter/record absent from cache; network unavailable |
| Flutter voice-state test runner with cached dependencies and `--no-pub` | Could not start: sandbox disallows binding local server socket (errno 1) |
| Full Flutter analysis/widget/API/controller tests | Not validated; dependencies unresolved |
| Docker Compose/migrations/PostgreSQL isolation | Not run: Docker socket permission denied; no dedicated DB supplied |
| Android APK/device recording/playback | Not run; dependency resolution and SDK build artifacts not validated |
| Real provider voice/chat smoke/native Darija evaluation | Not run; no configured credentials, real audio or device session |

## Known gaps and remaining work

1. Resolve dependencies on a network-enabled machine, produce reviewed lock files, run all backend/Flutter checks, fix compile/runtime findings and build/debug on a real Android device. Existing partial validation does not establish that the entire app builds.
2. Apply migrations to a restricted-role PostgreSQL instance, set `TEST_DATABASE_URL` to a dedicated migrated test DB, and execute cross-tenant RLS, retrieval and quota tests. Verify concurrent admission, cascades and retention against the actual DB.
3. Configure provider credentials and run the real voice smoke script, then verify the phone flow. Evaluate quiet/noisy Darija, code-switching, silence detection and selected TTS voice with native speakers. No benchmark results exist.
4. Obtain SaaS API/identity contract and staging credentials; implement real delegated read-only adapter, mobile OAuth PKCE/refresh/logout and JWKS rotation. Current token entry is development bootstrap only.
5. Add approved global knowledge, richer source permissions, authorized article/website ingestion and document management UI. Private document APIs exist; the mobile client currently exports/deletes conversation/preferences but does not upload/manage knowledge files.
6. Add real currency spending caps with configurable, dated price assumptions, fuller embedding/STT/TTS usage accounting and crash-safe billing reconciliation. Current unit quotas are conservative admission limits, not monthly currency caps.
7. Add scheduled inactive-user retention purge, full account deletion and complete usage/preference/document export without arbitrary message limits. Current lazy retention and bounded conversation export are incomplete for a final privacy product.
8. Add POST idempotency, stronger concurrency/cancellation integration coverage, adversarial prompt evaluations, PDF resource isolation, deployment/backup restore validation, Android release signing and accessibility/device checks. Process-local limiter supports one worker only.
9. Validate video/caption/blog/platform/appointment guidance with actual business data and native artisans. These currently use general Darija prompting, not separately verified feature workflows.

## Next recommended task

On a host with package downloads, local sockets and Docker access: resolve dependencies and run `scripts/check.sh`, execute dedicated PostgreSQL tests, then configure AI credentials and complete the first on-device Darija voice conversation. Keep real SaaS work blocked on its actual contract, not on guessed endpoints.

## Android APK generation attempt

On the follow-up request to generate the app, retried online Flutter dependency resolution and an actual `flutter build apk --debug --no-pub`. Dependency resolution failed with a pub.dev socket error. The first build hit the read-only shared Gradle cache; after copying that cache to a writable temporary location, Gradle started but failed creating `FileLockContentionHandler` because it could not determine a usable wildcard IP under the sandbox networking restrictions. No APK was produced. Flutter automatically upgraded the Android minimum SDK declaration to its supported template value during the build attempt.

Added `scripts/build_android.sh` and README build/install instructions. Shell syntax validation passed. The script resolves dependencies, runs Flutter analysis/tests and builds a development APK, copying it to `artifacts/le7rayfi-ai-debug.apk` only on success. Its complete build path is still unvalidated here. Generated APKs are ignored by Git. The temporary Gradle cache copy was removed after the failed build.
