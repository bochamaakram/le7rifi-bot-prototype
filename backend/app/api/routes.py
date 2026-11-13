import base64
import math
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import Response, JSONResponse
from sqlalchemy import select, func, delete
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool
from app.auth.identity import authenticate, Identity
from app.config.settings import get_settings, Settings
from app.models.database import scoped_session, owned, fields
from app.models.tables import Conversation, Message, Preference, Document, Chunk, Usage, TenantBudget, now
from app.schemas.api import ChatInput, SpeechInput, Preferences
from app.ai.providers.openai import OpenAIProvider, ProviderError
from app.ai.orchestrator import respond
from app.integrations.saas import MockSaaSAdapter
from app.speech.validation import validate_audio, InvalidAudio
from app.knowledge.ingestion import extract, chunks
from app.security.limits import limiter, reserve

router = APIRouter(prefix="/api/v1")


def get_provider(settings: Settings = Depends(get_settings)):
    return OpenAIProvider(settings)


def get_saas():
    return MockSaaSAdapter()


def admitted(identity: Identity = Depends(authenticate), settings: Settings = Depends(get_settings)):
    limiter.check(identity.tenant_id + ":" + identity.user_id, settings.max_requests_per_minute)
    return identity


def find(session, model, identity, id):
    row = session.scalar(owned(model, identity).where(model.id == id))
    if row is None:
        raise HTTPException(404, "not_found")
    return row


def serialize(row, names):
    return {name: getattr(row, name) for name in names}


def provider_failure(error):
    # Return rather than raise so quota reservations survive provider failure.
    return JSONResponse(status_code=503, content={"error": str(error)})


@router.get("/me")
def me(identity: Identity = Depends(admitted), settings: Settings = Depends(get_settings)):
    return {"user_id": identity.user_id, "tenant_id": identity.tenant_id,
            "auth_mode": settings.auth_mode, "saas_mode": settings.saas_mode}


@router.post("/conversations", status_code=201)
def create_conversation(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    row = Conversation(**fields(identity))
    session.add(row)
    session.flush()
    return serialize(row, ["id", "title", "created_at"])


@router.get("/conversations")
def conversations(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    return [serialize(row, ["id", "title", "created_at"]) for row in session.scalars(
        owned(Conversation, identity).order_by(Conversation.created_at.desc()).limit(100))]


@router.get("/conversations/{id}")
def conversation(id: str, identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    row = find(session, Conversation, identity, id)
    messages = session.scalars(owned(Message, identity).where(Message.conversation_id == id).order_by(Message.created_at).limit(500))
    return {**serialize(row, ["id", "title", "created_at"]),
            "messages": [serialize(m, ["id", "role", "content", "created_at"]) for m in messages]}


@router.delete("/conversations/{id}", status_code=204)
def delete_conversation(id: str, identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    session.delete(find(session, Conversation, identity, id))


@router.get("/business/context")
async def business_context(identity: Identity = Depends(admitted), saas=Depends(get_saas)):
    return await saas.context(identity)


@router.post("/chat/messages")
async def chat(body: ChatInput, identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function"),
               settings: Settings = Depends(get_settings), provider=Depends(get_provider), saas=Depends(get_saas)):
    conv = find(session, Conversation, identity, body.conversation_id)
    if not body.text.strip():
        raise HTTPException(422, "empty_message")
    usage = reserve(session, identity, settings, "chat", 3 if body.speech else 2)
    previous = list(session.scalars(owned(Message, identity).where(Message.conversation_id == conv.id)
                                   .order_by(Message.created_at.desc()).limit(12)))
    history = [{"role": m.role, "content": m.content} for m in reversed(previous)]
    docs = []
    try:
        if session.scalar(owned(Document, identity).limit(1)) is not None:
            vector = (await provider.embed([body.text]))[0]
            retrieved = session.scalars(owned(Chunk, identity).order_by(Chunk.embedding.cosine_distance(vector)).limit(4))
            docs = [{"id": c.document_id, "text": c.content} for c in retrieved]
        context = (await saas.context(identity)).model_dump()
        preference = session.scalar(owned(Preference, identity))
        if preference and preference.values.get("enabled"):
            context["approved_preferences"] = preference.values
        answer, counts = await respond(provider, body.text, history, context, docs, body.script)
    except ProviderError as error:
        return provider_failure(error)
    usage.input_tokens = int(counts.get("prompt_tokens", 0))
    usage.output_tokens = int(counts.get("completion_tokens", 0))
    session.add_all([Message(**fields(identity), conversation_id=conv.id, role="user", content=body.text),
                     Message(**fields(identity), conversation_id=conv.id, role="assistant", content=answer.text)])
    conv.title = conv.title if previous else body.text[:80]
    audio, speech_error = None, None
    if body.speech:
        try:
            audio = base64.b64encode(await provider.synthesize(answer.text[:3000])).decode()
        except ProviderError as error:
            speech_error = str(error)
    answer.speech_requested = body.speech
    return {"conversation_id": conv.id, "answer": answer.model_dump(),
            "audio_base64": audio, "audio_mime": "audio/mpeg" if audio else None, "speech_error": speech_error}


async def bounded_upload(file: UploadFile, limit: int):
    try:
        data = await file.read(limit + 1)
        if len(data) > limit:
            raise HTTPException(413, "upload_too_large")
        return data
    finally:
        await file.close()


@router.post("/speech/transcribe")
async def transcribe(file: UploadFile = File(...), identity: Identity = Depends(admitted),
                     session: Session = Depends(scoped_session, scope="function"), settings: Settings = Depends(get_settings),
                     provider=Depends(get_provider)):
    data = await bounded_upload(file, settings.max_audio_bytes)
    try:
        duration, filename = await run_in_threadpool(validate_audio, data, file.content_type,
                                                    settings.max_audio_bytes, settings.max_audio_seconds)
    except InvalidAudio as error:
        raise HTTPException(422, str(error)) from None
    usage = reserve(session, identity, settings, "transcription", math.ceil(duration / 15))
    usage.audio_seconds = math.ceil(duration)
    try:
        text = await provider.transcribe(data, filename, file.content_type)
        return {"text": text, "duration_seconds": duration}
    except ProviderError as error:
        return provider_failure(error)


@router.post("/speech/synthesize")
async def synthesize(body: SpeechInput, identity: Identity = Depends(admitted),
                     session: Session = Depends(scoped_session, scope="function"), settings: Settings = Depends(get_settings),
                     provider=Depends(get_provider)):
    reserve(session, identity, settings, "speech", math.ceil(len(body.text) / 1000))
    try:
        audio = await provider.synthesize(body.text)
        return Response(audio, media_type="audio/mpeg", headers={"Cache-Control": "no-store"})
    except ProviderError as error:
        return provider_failure(error)


@router.post("/knowledge/documents", status_code=201)
async def upload_document(file: UploadFile = File(...), identity: Identity = Depends(admitted),
                          session: Session = Depends(scoped_session, scope="function"), settings: Settings = Depends(get_settings),
                          provider=Depends(get_provider)):
    data = await bounded_upload(file, settings.max_document_bytes)
    try:
        text = await run_in_threadpool(extract, data, file.filename or "", file.content_type)
        parts = chunks(text)
        if len(parts) > settings.max_document_chunks:
            raise ValueError("too_many_chunks")
    except Exception:
        raise HTTPException(422, "invalid_document") from None
    reserve(session, identity, settings, "embedding", max(1, math.ceil(len(text) / 4000)))
    try:
        vectors = await provider.embed(parts)
    except ProviderError as error:
        return provider_failure(error)
    document = Document(**fields(identity), title=(file.filename or "Document")[:200])
    session.add(document)
    session.flush()
    session.add_all([Chunk(**fields(identity), document_id=document.id, content=part, embedding=vector)
                     for part, vector in zip(parts, vectors, strict=True)])
    return {"id": document.id, "title": document.title, "chunks": len(parts)}


@router.get("/knowledge/documents")
def documents(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    return [serialize(row, ["id", "title", "source", "language", "revision", "created_at"])
            for row in session.scalars(owned(Document, identity).order_by(Document.created_at.desc()).limit(100))]


@router.delete("/knowledge/documents/{id}", status_code=204)
def delete_document(id: str, identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    session.delete(find(session, Document, identity, id))


@router.get("/memory/preferences")
def preferences(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    row = session.scalar(owned(Preference, identity))
    return row.values if row else {"enabled": False, "script": "arabic", "response_length": "short"}


@router.put("/memory/preferences")
def save_preferences(body: Preferences, identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    row = session.scalar(owned(Preference, identity).with_for_update())
    if row is None:
        row = Preference(**fields(identity))
        session.add(row)
    row.values = body.model_dump() if body.enabled else {"enabled": False}
    return row.values


@router.delete("/memory/preferences", status_code=204)
def clear_preferences(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    session.execute(delete(Preference).where(Preference.tenant_id == identity.tenant_id, Preference.user_id == identity.user_id))


@router.get("/memory/export")
def export(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function")):
    return {"exported_at": now(), "preferences": preferences(identity, session),
            "conversations": [conversation(row.id, identity, session) for row in session.scalars(owned(Conversation, identity))],
            "documents": [{**serialize(d, ["id", "title", "source", "language", "revision"]),
                "chunks": [c.content for c in session.scalars(owned(Chunk, identity).where(Chunk.document_id == d.id))]}
                for d in session.scalars(owned(Document, identity))]}


@router.get("/usage")
def usage(identity: Identity = Depends(admitted), session: Session = Depends(scoped_session, scope="function"), settings: Settings = Depends(get_settings)):
    month = now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    base = select(func.coalesce(func.sum(Usage.units), 0)).where(Usage.tenant_id == identity.tenant_id, Usage.created_at >= month)
    rows = list(session.scalars(owned(Usage, identity).where(Usage.created_at >= month)))
    return {"month": month.isoformat(), "user_units": sum(r.units for r in rows), "tenant_units": session.scalar(select(TenantBudget.units).where(
                TenantBudget.tenant_id == identity.tenant_id, TenantBudget.month == month.strftime("%Y-%m"))) or 0,
            "user_limit": settings.monthly_units_per_user, "tenant_limit": settings.monthly_units_per_tenant,
            "input_tokens": sum(r.input_tokens for r in rows), "output_tokens": sum(r.output_tokens for r in rows),
            "audio_seconds": sum(r.audio_seconds for r in rows),
            "billing_notice": "Admission units are conservative quotas, not currency or guaranteed provider prices."}
