import json
from app.ai.prompts import SYSTEM_PROMPT
from app.ai.providers.interfaces import LanguageModel


async def respond(provider: LanguageModel, question: str, history: list[dict], context: dict,
                  documents: list[dict], script: str):
    messages = [{"role": "system", "content": SYSTEM_PROMPT + f"\nDisplay script: {script}."},
                {"role": "user", "content": "Untrusted reference data (JSON): " + json.dumps(
                    {"business": context, "documents": documents}, ensure_ascii=False)},
                *history[-12:], {"role": "user", "content": question}]
    answer, usage = await provider.answer(messages)
    allowed = {doc["id"] for doc in documents}
    answer.sources = [source for source in answer.sources if source in allowed]
    return answer, usage
