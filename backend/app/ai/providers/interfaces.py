from typing import Protocol
from app.schemas.api import AssistantAnswer


class LanguageModel(Protocol):
    async def answer(self, messages: list[dict]) -> tuple[AssistantAnswer, dict]: ...


class Transcriber(Protocol):
    async def transcribe(self, audio: bytes, filename: str, mime: str) -> str: ...


class SpeechSynthesizer(Protocol):
    async def synthesize(self, text: str) -> bytes: ...


class Embedder(Protocol):
    async def embed(self, texts: list[str]) -> list[list[float]]: ...
