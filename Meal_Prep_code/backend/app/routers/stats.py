"""Insights for the dashboard charts (customer spend / cook earnings)."""

from collections import Counter, defaultdict
from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Booking, BookingStatus, Role, User

router = APIRouter(prefix="/me", tags=["insights"])

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def _last_months(n: int) -> list[tuple[int, int]]:
    y, m = date.today().year, date.today().month
    out = []
    for _ in range(n):
        out.append((y, m))
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return list(reversed(out))


@router.get("/stats")
def stats(user: User = Depends(current_user), db: Session = Depends(get_db)):
    is_cook = user.role == Role.cook
    col = Booking.cook_id if is_cook else Booking.customer_id
    bookings = db.scalars(select(Booking).where(col == user.id)).all()

    months = _last_months(6)
    money = defaultdict(int)
    for b in bookings:
        if b.status == BookingStatus.completed:
            amount = b.price_estimate if not is_cook else round(b.price_estimate / 1.1)  # cook gets pre-fee amount
            money[(b.service_date.year, b.service_date.month)] += amount

    by_status = Counter(b.status.value for b in bookings)
    by_meal = Counter(b.meal_type.value for b in bookings)
    cuisines: Counter = Counter()
    if not is_cook:
        for b in bookings:
            for c in (b.cook.cuisines or [])[:1]:
                cuisines[c] += 1

    upcoming = [b for b in bookings if b.service_date >= date.today()
                and b.status in (BookingStatus.requested, BookingStatus.accepted)]
    completed = by_status.get("completed", 0)
    result = {
        "role": user.role.value,
        "monthly": [{"label": MONTHS[m - 1], "year": y, "amount": money[(y, m)]} for y, m in months],
        "total_amount": sum(money.values()),
        "completed": completed,
        "upcoming": len(upcoming),
        "by_status": dict(by_status),
        "by_meal_type": dict(by_meal),
        "by_cuisine": dict(cuisines.most_common(5)),
        "hours_saved": sum(b.duration_hours for b in bookings if b.status == BookingStatus.completed),
    }
    if is_cook and user.cook_profile:
        result["rating_avg"] = user.cook_profile.rating_avg
        result["rating_count"] = user.cook_profile.rating_count
        result["pending_requests"] = by_status.get("requested", 0)
    return result

