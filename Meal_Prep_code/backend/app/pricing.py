from .config import get_settings
from .schemas import QuoteOut

FREE_GUESTS = 4


def quote(hourly_rate: int, duration_hours: int, guests: int) -> QuoteOut:
    s = get_settings()
    cook_fee = hourly_rate * duration_hours
    extra = max(0, guests - FREE_GUESTS) * s.extra_guest_fee
    platform = round((cook_fee + extra) * s.platform_fee_pct / 100)
    return QuoteOut(cook_fee=cook_fee, extra_guest_fee=extra, platform_fee=platform, total=cook_fee + extra + platform)
