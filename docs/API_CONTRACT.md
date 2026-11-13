# API contract

Runtime OpenAPI at `/openapi.json`, interactive docs at `/docs`. All `/api/v1` operations require `Authorization: Bearer <access token>`. Identity and tenant fields in request bodies are forbidden. No endpoint writes to the SaaS.

| Method | Endpoint | Behavior |
|---|---|---|
| GET | `/health` | Liveness, no external calls |
| GET | `/ready` | DB/schema check and configuration flags |
| GET | `/api/v1/me` | Validated identity and development mode labels |
| POST | `/api/v1/conversations` | Create empty conversation; 201 |
| GET | `/api/v1/conversations` | Latest 100 owned conversations |
| GET | `/api/v1/conversations/{id}` | Owned conversation, oldest first, up to 500 messages |
| DELETE | `/api/v1/conversations/{id}` | Delete including messages; 204 |
| POST | `/api/v1/chat/messages` | Validated Darija answer and optional base64 MP3 |
| POST | `/api/v1/speech/transcribe` | Multipart `file`; measured duration and editable `text` |
| POST | `/api/v1/speech/synthesize` | `{text}` → raw `audio/mpeg` |
| GET | `/api/v1/business/context` | Explicitly mock read-only profile |
| POST | `/api/v1/knowledge/documents` | Multipart `file` → private document ID and chunk count; 201 |
| GET | `/api/v1/knowledge/documents` | Latest 100 owned document metadata records |
| DELETE | `/api/v1/knowledge/documents/{id}` | Delete document and embeddings; 204 |
| GET/PUT/DELETE | `/api/v1/memory/preferences` | Read/approve/clear preference memory |
| GET | `/api/v1/memory/export` | Export stored preferences, conversations and document chunks |
| GET | `/api/v1/usage` | User tokens/audio/units and aggregate tenant units for UTC month |

Chat request:

```json
{"conversation_id":"server-generated-id","text":"Bghit ndir video","script":"latin","speech":true}
```

Chat response:

```json
{
  "conversation_id":"server-generated-id",
  "answer":{"text":"...","follow_ups":[],"sources":[],"language":"darija-latin","speech_requested":true},
  "audio_base64":null,"audio_mime":null,"speech_error":"provider_unavailable"
}
```

Text success with TTS failure is HTTP 200 and preserves the response. A failed LLM/STT/embed request returns 503 with a safe machine code, never a mock answer. Conversation mutation is committed before success is sent. Structured source references contain only document IDs retrieved for that identity.

Preferences PUT requires `approved: true`. Allowed fields: `enabled`, `script` (`arabic`/`latin`), `response_length` (`short`/`normal`), `business_goals`, `content_preferences`. Disabling discards other preference values. These fields must not contain customer information. The phone's current script selection can work within a session without enabling memory.

Errors use `{"error":"machine_code"}`; validation adds field locations/types without echoing private inputs. Status: 401 invalid/missing token, 404 inaccessible resource (including foreign tenant), 413 excessive body/upload, 422 invalid input/media, 429 quota/rate/concurrent-tenant admission, 503 provider/DB unavailable. Request IDs are returned in `X-Request-ID` for handled requests. Do not automatically retry billable POSTs: after a timeout the outcome can be unknown. Idempotency keys are not implemented.

Audio MIME allowlist: WAV (`audio/wav`, `audio/x-wav`), M4A (`audio/mp4`), MP3 (`audio/mpeg`), WebM (`audio/webm`). Backend probes actual container, measures 0.1–60 seconds by default, decodes and rejects digital silence. This is not robust VAD; quiet/noisy recordings require evaluation. Defaults: 4 MB audio, 2 MB documents, 5 MB entire body; reverse proxy also limits body. PDF is bounded to 50 pages/100k characters; TXT/Markdown must be UTF-8. Large exports are not paginated yet.

Quotas: chat 2 units (+1 for requested speech), transcription ceil(duration/15), separate synthesis ceil(characters/1000), ingestion ceil(characters/4000). No refund on handled provider failure. Embedding/transcription token totals and exact synthesis duration are not yet accounted; LLM tokens and measured input audio are tracked. Unit limits are not currency spending caps.
