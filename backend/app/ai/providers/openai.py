import json
import httpx
from pydantic import ValidationError
from app.config.settings import Settings
from app.schemas.api import AssistantAnswer


class ProviderError(Exception):
    pass


class OpenAIProvider:
    """OpenAI-compatible HTTP adapter. No automatic retries on billable POSTs."""
    def __init__(self, settings: Settings):
        self.settings = settings

    async def request(self, path: str, **kwargs) -> httpx.Response:
        if not self.settings.provider_api_key:
            raise ProviderError("provider_not_configured")
        try:
            async with httpx.AsyncClient(timeout=self.settings.provider_timeout_seconds) as client:
                response = await client.post(self.settings.provider_base_url.rstrip("/") + path,
                                             headers={"Authorization": f"Bearer {self.settings.provider_api_key}"}, **kwargs)
                response.raise_for_status()
                return response
        except httpx.HTTPError:
            raise ProviderError("provider_unavailable") from None

    async def answer(self, messages: list[dict]) -> tuple[AssistantAnswer, dict]:
        response = await self.request("/chat/completions", json={
            "model": self.settings.llm_model, "messages": messages,
            "max_completion_tokens": self.settings.max_output_tokens,
            "response_format": {"type": "json_object"}})
        try:
            payload = response.json()
            answer = AssistantAnswer.model_validate_json(payload["choices"][0]["message"]["content"])
            return answer, payload.get("usage", {})
        except (ValueError, KeyError, IndexError, TypeError, ValidationError):
            raise ProviderError("invalid_provider_response") from None

    async def transcribe(self, audio: bytes, filename: str, mime: str) -> str:
        response = await self.request("/audio/transcriptions", files={"file": (filename, audio, mime)},
                                      data={"model": self.settings.stt_model,
                                            "prompt": "Moroccan Darija, français, العربية. حرفي، سباكة، نجارة، تسويق."})
        try:
            text = response.json()["text"].strip()
            if not text:
                raise ProviderError("no_speech_detected")
            return text
        except (KeyError, TypeError, ValueError):
            raise ProviderError("invalid_provider_response") from None

    async def synthesize(self, text: str) -> bytes:
        response = await self.request("/audio/speech", json={"model": self.settings.tts_model,
            "voice": self.settings.tts_voice, "input": text, "response_format": "mp3"})
        if not response.content:
            raise ProviderError("empty_audio_response")
        return response.content

    async def embed(self, texts: list[str]) -> list[list[float]]:
        response = await self.request("/embeddings", json={"model": self.settings.embedding_model,
            "input": texts, "dimensions": self.settings.embedding_dimensions})
        try:
            items = sorted(response.json()["data"], key=lambda row: row["index"])
            vectors = [row["embedding"] for row in items]
            if len(vectors) != len(texts) or any(len(v) != self.settings.embedding_dimensions for v in vectors):
                raise ValueError("Invalid embedding dimensions")
            return vectors
        except (ValueError, KeyError, TypeError):
            raise ProviderError("invalid_provider_response") from None
