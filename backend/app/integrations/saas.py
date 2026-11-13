from typing import Protocol
from pydantic import BaseModel
from app.auth.identity import Identity


class BusinessContext(BaseModel):
    mode: str
    verified: bool
    business_name: str
    profession: str
    city: str
    services: list[str]
    notice: str


class SaaSAdapter(Protocol):
    async def context(self, identity: Identity) -> BusinessContext: ...


class MockSaaSAdapter:
    async def context(self, identity: Identity) -> BusinessContext:
        return BusinessContext(mode="mock", verified=False, business_name="ورشة تجريبية",
            profession="نجار", city="الدار البيضاء", services=["إصلاح الأبواب", "صناعة الأثاث"],
            notice="بيانات تجريبية فقط — ماشي معلومات حقيقية من المنصة")


class RealSaaSAdapter:
    async def context(self, identity: Identity) -> BusinessContext:
        raise NotImplementedError("SaaS endpoints and delegated authorization contract required")
