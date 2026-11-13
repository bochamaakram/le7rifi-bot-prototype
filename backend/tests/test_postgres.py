"""Destructive to test schema: only use a dedicated migrated test database."""
import os
import uuid
import pytest
from sqlalchemy import create_engine, text, select
from sqlalchemy.orm import Session
from app.auth.identity import Identity
from app.models.tables import Conversation, Document, Chunk, Preference
from app.models.database import fields, owned
from app.api.routes import find
from app.security.limits import reserve
from app.config.settings import Settings
from fastapi import HTTPException

pytestmark = pytest.mark.skipif(not os.getenv('TEST_DATABASE_URL'), reason='Dedicated migrated PostgreSQL required')


def scope(session, identity):
    session.execute(text("SELECT set_config('app.tenant_id', :t, true), set_config('app.user_id', :u, true)"),
                    {'t': identity.tenant_id, 'u': identity.user_id})


def test_database_enforced_isolation_and_quota():
    engine = create_engine(os.environ['TEST_DATABASE_URL'])
    a = Identity('test-' + str(uuid.uuid4()), 'artisan-a', '')
    b = Identity('test-' + str(uuid.uuid4()), 'artisan-b', '')
    try:
        with Session(engine) as session, session.begin():
            role = session.execute(text('SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user')).one()
            assert not any(role), 'Isolation tests must use NOSUPERUSER NOBYPASSRLS'
            scope(session, a)
            conversation = Conversation(**fields(a), title='Private conversation')
            document = Document(**fields(a), title='Secret')
            session.add_all([conversation, document]); session.flush()
            chunk = Chunk(**fields(a), document_id=document.id, content='secret knowledge', embedding=[0.1] * 1536)
            session.add(chunk); session.flush()
            # Deliberately omit application predicates: RLS must still filter all tables.
            scope(session, b)
            assert session.scalars(select(Conversation)).all() == []
            assert session.scalars(select(Document)).all() == []
            assert session.scalars(select(Chunk).order_by(Chunk.embedding.cosine_distance([0.1] * 1536))).all() == []
            with pytest.raises(HTTPException) as error:
                find(session, Conversation, b, conversation.id)
            assert error.value.status_code == 404
            scope(session, a)
            assert session.scalar(select(Conversation).where(Conversation.id == conversation.id)) is not None
            settings = Settings(dev_token='x' * 40, monthly_units_per_user=1, monthly_units_per_tenant=1)
            reserve(session, a, settings, 'test')
            with pytest.raises(HTTPException) as error:
                reserve(session, a, settings, 'test')
            assert error.value.status_code == 429
            # Rollback test data, even on success.
            session.rollback()
    finally:
        engine.dispose()
