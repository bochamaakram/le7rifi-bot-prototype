# Implementation status

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
