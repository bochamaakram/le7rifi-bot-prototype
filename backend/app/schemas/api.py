from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ChatInput(StrictModel):
    conversation_id: str = Field(min_length=1, max_length=36)
    text: str = Field(min_length=1, max_length=4000)
    script: Literal["arabic", "latin"] = "arabic"
    speech: bool = True


class AssistantAnswer(StrictModel):
    text: str = Field(min_length=1, max_length=8000)
    follow_ups: list[str] = Field(default_factory=list, max_length=3)
    sources: list[str] = Field(default_factory=list, max_length=8)
    language: Literal["darija-arabic", "darija-latin", "mixed"] = "darija-arabic"
    speech_requested: bool = True


class SpeechInput(StrictModel):
    text: str = Field(min_length=1, max_length=3000)


class Preferences(StrictModel):
    enabled: bool = True
    script: Literal["arabic", "latin"] = "arabic"
    response_length: Literal["short", "normal"] = "short"
    business_goals: str = Field(default="", max_length=500)
    content_preferences: str = Field(default="", max_length=500)
    approved: Literal[True]
