from collections import defaultdict, deque
from threading import Lock
from time import monotonic
from fastapi import HTTPException
from sqlalchemy import select, func, text
from app.models.tables import Usage, TenantBudget, now
from app.models.database import fields


class RateLimiter:
    def __init__(self):
        self.windows = defaultdict(deque)
        self.lock = Lock()

    def check(self, key: str, limit: int):
        instant = monotonic()
        with self.lock:
            # Remove inactive identities to keep the process memory bounded.
            for old in list(self.windows):
                if not self.windows[old] or self.windows[old][-1] < instant - 60:
                    del self.windows[old]
            window = self.windows[key]
            while window and window[0] < instant - 60:
                window.popleft()
            if len(window) >= limit:
                raise HTTPException(429, "rate_limit", headers={"Retry-After": "60"})
            window.append(instant)


limiter = RateLimiter()


def reserve(session, identity, settings, operation: str, units: int = 1):
    # Serialize tenant budget admission, including concurrent users/requests.
    locked = session.scalar(text("SELECT pg_try_advisory_xact_lock(hashtextextended(:key, 0))"),
                            {"key": identity.tenant_id})
    if not locked:
        raise HTTPException(429, "tenant_request_in_progress", headers={"Retry-After": "2"})
    month = now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    base = select(func.coalesce(func.sum(Usage.units), 0)).where(
        Usage.tenant_id == identity.tenant_id, Usage.created_at >= month)
    budget = session.get(TenantBudget, (identity.tenant_id, month.strftime("%Y-%m")))
    if budget is None:
        budget = TenantBudget(tenant_id=identity.tenant_id, month=month.strftime("%Y-%m"), units=0)
        session.add(budget)
    tenant = budget.units
    user = session.scalar(base.where(Usage.user_id == identity.user_id))
    if tenant + units > settings.monthly_units_per_tenant or user + units > settings.monthly_units_per_user:
        raise HTTPException(429, "monthly_usage_limit")
    budget.units += units
    row = Usage(**fields(identity), operation=operation, units=units)
    session.add(row)
    session.flush()
    return row
