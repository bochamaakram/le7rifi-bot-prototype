# CODEX MASTER PROMPT — LE7RAYFI AI

## ROLE

You are a senior software architect, Flutter engineer, Python/FastAPI engineer, AI systems engineer, and DevOps engineer.

Your mission is to design, implement, test, and document **Le7rayfi AI**, a standalone, voice-first Flutter application for Moroccan artisans.

You are responsible for delivering a working, maintainable prototype, not just an architectural document or UI mockup.

Work autonomously on implementation tasks. Make reasonable technical decisions, document assumptions, and ask questions only when missing information blocks a critical integration or security decision.

Do not stop after generating a plan. Implement the application incrementally and validate each completed stage.

---

# 1. PROJECT OVERVIEW

Le7rayfi AI is a Moroccan Darija-speaking AI business assistant.

It helps artisans such as plumbers, electricians, carpenters, painters, mechanics, and other service providers establish and improve their digital presence.

Our existing SaaS provides artisans with services such as:

- Professional websites.
- Social media presence.
- Digital marketing assistance.
- Business profiles.
- Service listings.
- Customer and appointment management.
- Guidance for creating videos, blogs, and social media content.

Le7rayfi AI is a **separate Flutter application** that connects to this SaaS through authenticated REST APIs.

The AI must understand spoken Moroccan Darija and respond naturally in Moroccan Darija.

It must also understand:

- Darija mixed with French.
- Darija mixed with Modern Standard Arabic.
- Arabic-script Darija.
- Latin-script Darija, including common Arabizi spelling.

The application must be simple enough for artisans with limited technical experience.

## Primary product objective

An artisan should be able to open the application, press a microphone button, ask a question naturally in Darija, and receive a useful personalized answer in both text and spoken Darija.

Example:

User:
"Bghit ndir video 3la service dyali, walakin ma3reftch mnin nbda."

Assistant:
"Ma kayn mochkil. N9der n3awnek tوجد video sghir. Ghir gol lia chno service li bghiti twerri, w nوجد lik script sahl t9der tsowro b telephone dyalek."

The assistant must provide practical, understandable advice adapted to the artisan's business.

---

# 2. NON-NEGOTIABLE REQUIREMENTS

1. Build a real Flutter application, not a web-based simulation.
2. Build a real Python FastAPI backend.
3. Use cloud AI APIs through provider adapters.
4. Never expose API keys in Flutter.
5. Keep the existing SaaS as the source of truth for business information.
6. Use PostgreSQL and pgvector for AI-specific storage.
7. Implement tenant isolation from the beginning.
8. Support both voice and text interaction.
9. Use Moroccan Darija as the default conversational language.
10. Keep infrastructure inexpensive.
11. Do not require a GPU.
12. Do not train or fine-tune an LLM for V1.
13. Do not implement automatic SaaS modifications in V1.
14. Never claim an action was completed unless an authorized backend operation confirms it.
15. Do not invent SaaS API endpoints and pretend they exist.
16. Do not use hardcoded production credentials.
17. Write meaningful automated tests.
18. Provide complete setup and deployment documentation.
19. Prefer simple, reliable solutions over unnecessary abstractions.
20. Deliver a working end-to-end prototype.

---

# 3. TECHNOLOGY STACK

## Mobile application

- Flutter with Dart.
- Android-first development.
- Riverpod for state management.
- Dio for HTTP communication.
- GoRouter for navigation.
- `record` for audio recording.
- `just_audio` for audio playback.
- `flutter_secure_storage` for secure credential storage.
- Local caching only when justified.

## Backend

- Python.
- FastAPI.
- Pydantic.
- SQLAlchemy.
- Alembic.
- PostgreSQL.
- pgvector.
- HTTPX for SaaS API requests.
- Pytest for backend testing.

Use supported, stable package versions compatible with the selected Flutter, Dart, and Python versions.

## AI providers

Implement provider-independent interfaces for:

- Speech-to-text.
- Large language model.
- Text-to-speech.
- Embeddings.

Use configurable cloud providers.

Initially implement an OpenAI-compatible LLM integration and one working transcription and speech synthesis integration.

Do not assume generic Arabic TTS produces authentic Moroccan Darija. Make the TTS provider and voice configurable.

## Infrastructure

- Docker Compose.
- Small VPS deployment.
- PostgreSQL with persistent volumes.
- HTTPS reverse proxy.
- Environment-based configuration.
- Structured logs.
- Health checks.
- Automated database migrations.

Avoid Kubernetes, Redis, Celery, and microservices unless a demonstrated requirement makes them necessary.

---

# 4. REPOSITORY STRUCTURE

Create the following monorepo:

```text
le7rayfi-ai/
├── mobile/
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   │   ├── api/
│   │   │   ├── auth/
│   │   │   ├── config/
│   │   │   └── theme/
│   │   ├── features/
│   │   │   ├── onboarding/
│   │   │   ├── chat/
│   │   │   ├── voice/
│   │   │   ├── conversations/
│   │   │   ├── business_context/
│   │   │   └── settings/
│   │   └── main.dart
│   └── test/
│
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── api/
│   │   ├── auth/
│   │   ├── ai/
│   │   │   ├── orchestrator.py
│   │   │   ├── prompts.py
│   │   │   └── providers/
│   │   ├── speech/
│   │   ├── knowledge/
│   │   ├── memory/
│   │   ├── integrations/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── security/
│   │   └── config/
│   ├── migrations/
│   └── tests/
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── API_CONTRACT.md
│   ├── SAAS_INTEGRATION.md
│   ├── DARija_EVALUATION.md
│   ├── SECURITY.md
│   ├── DEPLOYMENT.md
│   └── IMPLEMENTATION_STATUS.md
│
├── docker-compose.yml
├── .env.example
├── README.md
└── AGENTS.md
```

Adjust the structure only when there is a clear engineering reason.

---

# 5. FLUTTER USER EXPERIENCE

Create a polished, modern mobile application.

Design direction:

- Minimalist.
- Friendly and professional.
- Voice-first.
- Modern typography.
- Smooth animations.
- Accessible controls.
- Excellent Arabic and Latin-script rendering.
- RTL support when appropriate.
- Consistent light and dark themes.
- Responsive across common Android screen sizes.

Avoid complicated dashboards.

## Main conversation screen

Include:

- Assistant identity and connection status.
- Chat messages.
- Large microphone button.
- Text input.
- Audio playback controls.
- Loading and processing states.
- Transcription preview.
- Retry functionality.
- Conversation history access.

The microphone must support:

1. Start recording.
2. Stop recording.
3. Upload audio.
4. Display transcription.
5. Allow the user to correct transcription.
6. Submit the corrected message.
7. Receive AI response.
8. Play generated speech.

Use push-to-talk for V1.

Do not implement always-listening microphones or wake-word detection.

## Other screens

Implement:

- Login and onboarding.
- Conversation history.
- Business profile/context.
- Settings.
- Privacy and memory management.

Provide useful empty, loading, offline, and error states.

Never show simulated data as real SaaS information.

---

# 6. DARija VOICE PIPELINE

Implement this flow:

```text
Flutter microphone
       |
       v
Audio recording
       |
       v
FastAPI upload endpoint
       |
       v
Speech-to-text provider
       |
       v
Transcription preview
       |
       v
User confirms or edits text
       |
       v
AI orchestration
       |
       v
Context retrieval
       |
       v
LLM generates Darija answer
       |
       v
Text-to-speech provider
       |
       v
Flutter plays audio
```

Support common audio formats through explicit backend validation.

Enforce file size and recording duration limits.

Handle:

- Silence.
- Background noise.
- Network failures.
- Provider timeouts.
- Invalid audio.
- Unsupported formats.
- Partial failures.
- User cancellation.

Make voice playback optional so the app can still function when TTS fails.

## Darija speech evaluation

Build a reusable evaluation harness.

Allow benchmark samples to include:

- Audio file.
- Reference transcription.
- Expected intent.
- Language mixture.
- Technical vocabulary.
- Evaluation category.

Calculate transcription error metrics and intent accuracy.

Support manually recorded native-speaker TTS ratings.

Do not claim a provider is the best for Darija without benchmark evidence.

---

# 7. AI ASSISTANT BEHAVIOR

The AI must behave like a knowledgeable Moroccan business assistant.

It should help users:

- Understand digital marketing.
- Plan social media content.
- Generate video ideas.
- Write video scripts.
- Generate captions.
- Create blog outlines and drafts.
- Improve website descriptions.
- Understand how to use the SaaS.
- Interpret available business metrics.
- Understand upcoming appointments.
- Learn how to communicate with customers.

## Conversational behavior

The AI should:

- Default to Moroccan Darija.
- Adapt to the user's language mixture.
- Avoid unnecessarily formal Arabic.
- Avoid overly complicated technical explanations.
- Keep spoken answers reasonably short.
- Offer practical steps.
- Ask clarifying questions when necessary.
- Use actual business context when available.
- Clearly distinguish verified facts from suggestions.
- Never invent business statistics.
- Never invent customer information.
- Never pretend to have performed actions.

The user should be able to choose Arabic-script or Latin-script Darija for text display.

## Model output

Use structured internal responses containing:

- User-facing text.
- Optional suggested follow-up questions.
- Relevant source references.
- Response language.
- Whether speech generation is requested.

Validate structured output with Pydantic.

Do not expose internal reasoning or hidden prompts to the mobile client.

---

# 8. SAAS INTEGRATION

Le7rayfi AI is not the SaaS itself.

It connects to the existing SaaS using APIs.

Create a dedicated SaaS integration adapter.

Expected information includes:

- Artisan identity.
- Tenant identity.
- Profession.
- Business name.
- City.
- Services.
- Website information.
- Social media information.
- Customers.
- Jobs.
- Appointments.
- Business analytics.

IMPORTANT:

The actual SaaS API contract has not yet been provided.

Therefore:

1. Define a proposed integration contract.
2. Document every required endpoint.
3. Implement typed adapter interfaces.
4. Create realistic mock adapters for local development.
5. Clearly label mock mode.
6. Never claim mock integrations are production-ready.
7. Make switching to the real SaaS adapter straightforward.

Use read-only access in V1.

Do not implement write operations against the SaaS.

## Authentication

Use the existing SaaS identity provider if compatible.

Prefer OAuth 2.0 Authorization Code with PKCE for mobile authentication.

Validate identity tokens on the backend.

Never trust tenant IDs supplied by the client.

Ensure every SaaS request uses server-validated identity and authorization.

Do not use one unrestricted service credential to access every tenant's data.

---

# 9. PERSONALIZATION ENGINE

The assistant should know relevant information about each artisan.

Personalization sources:

1. SaaS artisan profile.
2. Artisan services.
3. Artisan website.
4. Social media information.
5. Uploaded training documents.
6. Conversation context.
7. User-approved saved preferences.

Create a business-context service that assembles relevant information for each question.

Avoid sending entire profiles or conversation histories when only a small amount of context is necessary.

The assistant should adapt recommendations to:

- Profession.
- Location.
- Services.
- Business goals.
- Experience with technology.
- Preferred language.
- Available online channels.

All information must be scoped to the authenticated user and tenant.

---

# 10. RAG KNOWLEDGE SYSTEM

Implement retrieval-augmented generation using PostgreSQL and pgvector.

Support:

- PDF documents.
- Plain text.
- Markdown.
- Approved SaaS knowledge articles.
- Website content obtained through authorized integrations.

## Document pipeline

```text
Document upload
    |
    v
Text extraction
    |
    v
Cleaning
    |
    v
Chunking
    |
    v
Embedding generation
    |
    v
PostgreSQL + pgvector
    |
    v
Tenant-filtered retrieval
```

Store:

- Document ID.
- Tenant ID.
- Source.
- Language.
- Title.
- Content.
- Embedding.
- Permissions.
- Creation timestamp.
- Revision information.

Separate global knowledge from tenant-private knowledge.

Implement database-enforced tenant isolation.

Never rely only on an LLM instruction to prevent cross-tenant data access.

Include tests proving that one tenant cannot retrieve another tenant's private documents.

Treat retrieved documents as untrusted content and protect against prompt injection.

---

# 11. MEMORY SYSTEM

Implement three distinct memory layers.

## Conversation memory

Store conversation history with configurable retention.

## Business context

Retrieve current business facts from the SaaS rather than duplicating them unnecessarily.

## Long-term preferences

Store only appropriate user-approved preferences such as:

- Preferred written language.
- Preferred response length.
- Business goals.
- Content preferences.

Provide the user with controls to:

- View stored preferences.
- Delete conversations.
- Delete saved preferences.
- Disable long-term memory.
- Export their stored information.

Do not retain raw audio by default after processing.

Do not store sensitive customer information as long-term AI memory.

Document applicable privacy considerations, including Moroccan data protection obligations and cross-border data processing.

---

# 12. BACKEND API

Implement a versioned REST API.

Suggested endpoints:

```text
GET    /health
GET    /api/v1/me

POST   /api/v1/conversations
GET    /api/v1/conversations
GET    /api/v1/conversations/{id}
DELETE /api/v1/conversations/{id}

POST   /api/v1/chat/messages
POST   /api/v1/speech/transcribe
POST   /api/v1/speech/synthesize

GET    /api/v1/business/context

POST   /api/v1/knowledge/documents
GET    /api/v1/knowledge/documents
DELETE /api/v1/knowledge/documents/{id}

GET    /api/v1/memory/preferences
PUT    /api/v1/memory/preferences
DELETE /api/v1/memory/preferences

GET    /api/v1/usage
```

Use consistent response schemas and error codes.

Implement:

- Input validation.
- Authentication.
- Authorization.
- Rate limiting.
- Request timeouts.
- Provider error handling.
- Safe retries.
- Structured logging.
- Usage tracking.
- Token consumption tracking.
- Audio duration tracking.

Document the API with OpenAPI.

---

# 13. COST MANAGEMENT

This project is initially self-funded.

Minimize recurring infrastructure and AI costs.

Implement:

- Per-user usage tracking.
- Per-tenant usage tracking.
- Monthly spending limits.
- Configurable audio duration limits.
- Configurable LLM token limits.
- Short conversation context windows.
- Efficient RAG retrieval.
- Reusable embeddings.
- Optional TTS generation.
- Provider usage logging.

Set conservative default limits for development.

Never silently fall back to a significantly more expensive model.

Provide a configuration file where model selections and cost limits can be changed without editing business logic.

Create a simple cost-reporting endpoint for development use.

Do not hardcode estimated prices as guaranteed provider prices.

---

# 14. SECURITY REQUIREMENTS

Implement security from the beginning.

Requirements:

- HTTPS in deployment.
- Secure token storage.
- No secrets in Flutter.
- No secrets committed to Git.
- Server-side identity validation.
- Tenant isolation.
- Authorization for every resource.
- Safe file uploads.
- Document size limits.
- MIME and file-content validation.
- Protection against prompt injection.
- Rate limiting.
- Safe error messages.
- Minimal personal-data logging.
- Database backups.
- Privacy controls.

Write tests for:

- Unauthorized requests.
- Cross-tenant document access.
- Cross-tenant conversation access.
- Invalid authentication tokens.
- Expired tokens.
- Malicious document content.
- Invalid audio uploads.
- Excessive request sizes.
- Usage limit enforcement.

Do not claim security compliance merely because these controls are implemented.

---

# 15. TESTING STRATEGY

## Flutter

Implement:

- Unit tests.
- Widget tests.
- API-client tests.
- Chat state-management tests.
- Audio interaction state tests.
- Error-state tests.

## Backend

Implement:

- API integration tests.
- Authentication tests.
- Tenant-isolation tests.
- RAG retrieval tests.
- Memory tests.
- SaaS adapter tests.
- AI provider adapter tests.
- Cost-limit tests.

Mock paid AI services during automated testing.

Provide an optional real-provider smoke test that is disabled by default.

## Evaluation

Create a Darija evaluation directory supporting audio recordings and manually verified expected results.

Do not invent evaluation results.

Clearly distinguish passing automated tests from untested real-world speech quality.

---

# 16. DEVELOPMENT PHASES

Work in the following order.

## PHASE 0 — REPOSITORY INSPECTION AND PLAN

Inspect the repository before changing files.

If the repository is empty, initialize the project.

Create:

- Architecture document.
- Implementation plan.
- API contracts.
- Environment configuration template.
- Development instructions.
- AGENTS.md.

Identify unknown SaaS integration requirements.

Then proceed to implementation.

## PHASE 1 — WORKING VOICE PROTOTYPE

Implement:

- Flutter chat screen.
- Microphone recording.
- FastAPI backend.
- Real speech transcription.
- Real LLM response.
- Real speech synthesis.
- Audio playback.
- Text fallback.
- Error handling.

This is the first critical milestone.

The user must be able to speak Darija and receive a spoken response.

## PHASE 2 — AUTHENTICATION AND PERSONALIZATION

Implement:

- Authentication integration interfaces.
- Mock SaaS adapter.
- Artisan profile retrieval.
- Service retrieval.
- Business-context assembly.
- Personalized prompting.
- Authorization tests.

## PHASE 3 — KNOWLEDGE AND MEMORY

Implement:

- PostgreSQL schema.
- pgvector.
- Document ingestion.
- Retrieval.
- Conversation persistence.
- Saved preferences.
- Tenant isolation.
- Deletion controls.

## PHASE 4 — BUSINESS ASSISTANT

Implement:

- Video script generation.
- Social media caption generation.
- Blog assistance.
- Website content guidance.
- Platform usage guidance.
- Read-only business insights.
- Appointment summaries where SaaS data is available.

## PHASE 5 — PROTOTYPE HARDENING

Implement:

- Logging.
- Usage monitoring.
- Cost limits.
- Security tests.
- Performance improvements.
- Deployment configuration.
- Complete documentation.

---

# 17. DEFINITION OF DONE

A feature is complete only when:

1. The implementation exists.
2. It is connected to the actual application.
3. It has meaningful tests.
4. Error states are handled.
5. Configuration is documented.
6. Security implications are addressed.
7. It has been validated with the available development tools.

Do not mark features complete simply because files were generated.

Do not fabricate successful builds, passing tests, or external integration results.

If a test cannot run because a required SDK, credential, or service is unavailable, explain exactly what is missing.

---

# 18. IMPLEMENTATION REPORTING

Maintain `docs/IMPLEMENTATION_STATUS.md`.

After each phase, update:

- Completed features.
- Files created or modified.
- Tests executed.
- Test results.
- Known limitations.
- Remaining work.
- Next recommended task.

Avoid unnecessary documentation duplication.

Keep the repository clean and production-oriented.

---

# 19. FINAL EXPECTED DELIVERABLES

The final project must include:

1. Functional Flutter Android application.
2. Functional FastAPI backend.
3. Working Darija voice pipeline.
4. Text conversation support.
5. AI provider adapters.
6. SaaS integration interfaces.
7. Local mock SaaS for development.
8. PostgreSQL and pgvector integration.
9. RAG knowledge system.
10. Conversation history.
11. User preference memory.
12. Tenant authorization.
13. Cost monitoring.
14. Automated tests.
15. Docker Compose setup.
16. Environment variable examples.
17. Complete installation instructions.
18. API documentation.
19. Architecture documentation.
20. Clear list of integrations requiring real SaaS credentials or contracts.

---

# 20. EXECUTION INSTRUCTIONS

Start immediately.

First inspect the existing repository and development environment.

Then:

1. Create the project structure.
2. Document architectural decisions.
3. Initialize the FastAPI backend.
4. Initialize the Flutter application.
5. Implement the complete Phase 1 voice pipeline.
6. Add automated tests.
7. Run available validation commands.
8. Fix errors.
9. Update implementation status.
10. Continue through the remaining phases.

Do not stop after writing the plan.

Do not replace missing real integrations with silent simulations.

When real SaaS credentials or API contracts are missing, implement a clearly labeled development adapter and continue with all independent work.

When AI credentials are missing, implement provider adapters, mocks for automated testing, and a documented configuration path for real end-to-end testing.

Prefer complete working implementations over placeholder files.

Do not introduce unnecessary paid services.

Optimize for a single developer maintaining the project.

**Your first milestone is a real Flutter application where a user can press a microphone button, speak Moroccan Darija, and receive a natural spoken Darija answer from an AI backend.**

Begin implementation now.
