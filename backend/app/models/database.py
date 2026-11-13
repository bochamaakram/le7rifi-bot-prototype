from functools import lru_cache
from fastapi import Depends
from sqlalchemy import create_engine, text, select, delete
from sqlalchemy.orm import Session
from app.auth.identity import Identity, authenticate
from app.config.settings import get_settings
from app.models.tables import Conversation, Message, now
from datetime import timedelta


@lru_cache
def engine():
    return create_engine(get_settings().database_url, pool_pre_ping=True)


def scoped_session(identity: Identity = Depends(authenticate)):
    with Session(engine()) as session:
        with session.begin():
            session.execute(text("SELECT set_config('app.tenant_id', :tenant, true), set_config('app.user_id', :user, true)"),
                            {"tenant": identity.tenant_id, "user": identity.user_id})
            cutoff = now() - timedelta(days=get_settings().retention_days)
            old = select(Conversation.id).where(Conversation.tenant_id == identity.tenant_id,
                                               Conversation.user_id == identity.user_id,
                                               Conversation.created_at < cutoff)
            session.execute(delete(Message).where(Message.conversation_id.in_(old)))
            session.execute(delete(Conversation).where(Conversation.id.in_(old)))
            yield session


def owned(model, identity):
    return select(model).where(model.tenant_id == identity.tenant_id, model.user_id == identity.user_id)


def fields(identity):
    return {"tenant_id": identity.tenant_id, "user_id": identity.user_id}
