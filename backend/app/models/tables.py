import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Text, DateTime, JSON, Integer, ForeignKey
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from pgvector.sqlalchemy import Vector


def now():
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Private:
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id: Mapped[str] = mapped_column(String(200), index=True)
    user_id: Mapped[str] = mapped_column(String(200), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Conversation(Private, Base):
    __tablename__ = "conversations"
    title: Mapped[str] = mapped_column(String(80), default="محادثة جديدة")


class Message(Private, Base):
    __tablename__ = "messages"
    conversation_id: Mapped[str] = mapped_column(ForeignKey("conversations.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(20))
    content: Mapped[str] = mapped_column(Text)


class Preference(Private, Base):
    __tablename__ = "preferences"
    values: Mapped[dict] = mapped_column(JSON, default=dict)


class Document(Private, Base):
    __tablename__ = "documents"
    title: Mapped[str] = mapped_column(String(200))
    source: Mapped[str] = mapped_column(String(50), default="user_upload")
    language: Mapped[str] = mapped_column(String(30), default="mixed")
    revision: Mapped[int] = mapped_column(Integer, default=1)
    permissions: Mapped[dict] = mapped_column(JSON, default=lambda: {"scope": "private"})


class Chunk(Private, Base):
    __tablename__ = "chunks"
    document_id: Mapped[str] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), index=True)
    content: Mapped[str] = mapped_column(Text)
    embedding: Mapped[list[float]] = mapped_column(Vector(1536))


class Usage(Private, Base):
    __tablename__ = "usage"
    operation: Mapped[str] = mapped_column(String(40))
    units: Mapped[int] = mapped_column(Integer, default=1)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    audio_seconds: Mapped[int] = mapped_column(Integer, default=0)


class TenantBudget(Base):
    __tablename__ = "tenant_budgets"
    tenant_id: Mapped[str] = mapped_column(String(200), primary_key=True)
    month: Mapped[str] = mapped_column(String(7), primary_key=True)
    units: Mapped[int] = mapped_column(Integer, default=0)
