"""Tools the AI agents can call. Each returns (result_for_model, ui_block_or_None).

UI blocks are rendered as rich cards in the app (cook list, meal plan, grocery list, booking
draft with a Confirm button…). Anything that changes data the user cares about (bookings,
profile edits) is only *drafted* here; the user confirms it in the app.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, time
from statistics import mean
from typing import Any, Callable

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..foods import search_foods
from ..models import Address, Booking, BookingStatus, CookProfile, MealPlan, MealType, Role, User
from ..plans import grocery_list, nutrition_summary
from ..pricing import quote
from ..routers.meal_plans import (
    MealPlanIn,
    create_plan,
    plan_detail,
    plan_summary,
    visible_plans_query,
)


class ToolError(Exception):
    """Raised for bad arguments; the message is sent back to the model so it can recover."""


@dataclass
class ToolContext:
    db: Session
    user: User
    blocks: list[dict] = field(default_factory=list)


@dataclass
class Tool:
    name: str
    description: str
    parameters: dict
    fn: Callable[..., Any]

    def schema(self) -> dict:
        return {"name": self.name, "description": self.description, "parameters": self.parameters}


def _obj(props: dict, required: list[str] | None = None) -> dict:
    return {"type": "object", "properties": props, "required": required or []}


def _cook_dict(p: CookProfile) -> dict:
    return {
        "user_id": p.user_id, "name": p.user.name, "bio": p.bio, "cuisines": p.cuisines, "languages": p.languages,
        "service_pincodes": p.service_pincodes, "veg_only": p.veg_only, "experience_years": p.experience_years,
        "hourly_rate": p.hourly_rate, "rating_avg": p.rating_avg, "rating_count": p.rating_count,
        "verified": p.verified, "is_active": p.is_active,
    }


def _plan(ctx: ToolContext, plan_id: int) -> MealPlan:
    p = ctx.db.get(MealPlan, int(plan_id))
    if not p or (p.owner_id is not None and p.owner_id != ctx.user.id):
        raise ToolError(f"No meal plan with id {plan_id}. Use list_meal_plans to find ids.")
    return p


# ================================================================ customer tools
def search_cooks(ctx: ToolContext, pincode: str | None = None, cuisine: str | None = None,
                 veg_only: bool = False, max_rate: int | None = None, limit: int = 6):
    q = select(CookProfile).where(CookProfile.is_active.is_(True))
    if pincode:
        q = q.where(CookProfile.service_pincodes.any(str(pincode)))
    if veg_only:
        q = q.where(CookProfile.veg_only.is_(True))
    if max_rate:
        q = q.where(CookProfile.hourly_rate <= int(max_rate))
    cooks = ctx.db.scalars(q.order_by(CookProfile.verified.desc(), CookProfile.rating_avg.desc())).all()
    if cuisine:
        c = cuisine.lower()
        cooks = [p for p in cooks if any(c in x.lower() or x.lower() in c for x in p.cuisines)]
    cooks = cooks[: max(1, min(int(limit), 10))]
    data = [_cook_dict(p) for p in cooks]
    if data:
        ctx.blocks.append({"type": "cooks", "cooks": data})
    return {"count": len(data), "cooks": [
        {k: d[k] for k in ("user_id", "name", "cuisines", "hourly_rate", "rating_avg", "rating_count",
                           "verified", "veg_only", "experience_years", "service_pincodes")}
        for d in data
    ]}


def get_cook_details(ctx: ToolContext, cook_id: int):
    p = ctx.db.get(CookProfile, int(cook_id))
    if not p:
        raise ToolError(f"No cook with id {cook_id}")
    d = _cook_dict(p)
    d["dishes"] = [{"id": x.id, "name": x.name, "cuisine": x.cuisine, "is_veg": x.is_veg} for x in p.dishes]
    return d


def list_meal_plans(ctx: ToolContext, goal: str | None = None, diet: str | None = None):
    q = visible_plans_query(ctx.user)
    if goal:
        q = q.where(MealPlan.goal == goal)
    if diet:
        q = q.where(MealPlan.diet == diet)
    plans = [plan_summary(p) for p in ctx.db.scalars(q.order_by(MealPlan.id)).all()]
    if plans:
        ctx.blocks.append({"type": "meal_plans", "plans": plans})
    return {"plans": [{k: p[k] for k in ("id", "title", "goal", "diet", "cuisine", "avg_kcal", "avg_protein")}
                      for p in plans]}


def get_meal_plan(ctx: ToolContext, plan_id: int):
    p = _plan(ctx, plan_id)
    d = plan_detail(p)
    ctx.blocks.append({"type": "meal_plan", "plan": plan_summary(p)})
    return {
        "id": d["id"], "title": d["title"], "diet": d["diet"], "daily_average": d["nutrition"]["daily_average"],
        "days": [{"day": x["label"], "meals": {m["slot"]: m["name"] for m in x["meals"]}} for x in d["days"]],
    }


def find_dishes(ctx: ToolContext, query: str = "", diet: str | None = None):
    return {"dishes": [
        {"key": f.key, "name": f.name, "cuisine": f.cuisine, "diet": f.diet, "kcal": f.kcal, "protein": f.protein}
        for f in search_foods(query, diet, limit=40)
    ]}


def create_meal_plan(ctx: ToolContext, title: str, days: list, goal: str = "balanced", diet: str = "veg",
                     description: str = "", cuisine: str = "Mixed", emoji: str = "✨"):
    try:
        body = MealPlanIn(title=title, days=days, goal=goal, diet=diet, description=description,
                          cuisine=cuisine, emoji=emoji, color="#7C4DFF", tags=["AI generated"])
    except Exception as exc:  # pydantic validation
        raise ToolError(f"Invalid plan: {exc}") from exc
    p = create_plan(ctx.db, ctx.user, body, by_ai=True)
    ctx.blocks.append({"type": "meal_plan", "plan": plan_summary(p)})
    n = nutrition_summary(p.days)
    return {"saved_plan_id": p.id, "title": p.title, "daily_average": n["daily_average"],
            "note": "Plan saved to the user's Plans tab and shown as a card."}


def plan_nutrition(ctx: ToolContext, plan_id: int):
    p = _plan(ctx, plan_id)
    n = nutrition_summary(p.days)
    ctx.blocks.append({"type": "nutrition", "plan_id": p.id, "title": p.title, "nutrition": n})
    return n


def plan_grocery_list(ctx: ToolContext, plan_id: int, people: int = 2):
    p = _plan(ctx, plan_id)
    people = max(1, min(int(people), 30))
    cats = grocery_list(p.days, people)
    ctx.blocks.append({"type": "grocery_list", "plan_id": p.id, "title": p.title, "people": people, "categories": cats})
    return {"people": people, "categories": [{"category": c["category"], "items": len(c["items"])} for c in cats],
            "note": "Full list shown to the user as a checklist card."}


def get_price_quote(ctx: ToolContext, cook_id: int, duration_hours: int = 2, guests: int = 2):
    p = ctx.db.get(CookProfile, int(cook_id))
    if not p:
        raise ToolError(f"No cook with id {cook_id}")
    return quote(p.hourly_rate, int(duration_hours), int(guests)).model_dump()


def list_my_addresses(ctx: ToolContext):
    addrs = ctx.db.scalars(select(Address).where(Address.user_id == ctx.user.id)).all()
    return {"addresses": [{"id": a.id, "label": a.label, "area": a.area, "pincode": a.pincode} for a in addrs]}


def draft_booking(ctx: ToolContext, cook_id: int, service_date: str, start_time: str, meal_type: str = "lunch",
                  duration_hours: int = 2, guests: int = 2, address_id: int | None = None, notes: str = "",
                  meal_plan_id: int | None = None):
    cook = ctx.db.get(CookProfile, int(cook_id))
    if not cook or not cook.is_active:
        raise ToolError("That cook isn't available.")
    try:
        d = date.fromisoformat(service_date)
        t = time.fromisoformat(start_time if len(start_time) > 5 else start_time + ":00")
    except ValueError as exc:
        raise ToolError("Use service_date YYYY-MM-DD and start_time HH:MM.") from exc
    if d < date.today():
        raise ToolError("That date is in the past.")
    if meal_type not in {m.value for m in MealType}:
        raise ToolError(f"meal_type must be one of {[m.value for m in MealType]}")
    addrs = ctx.db.scalars(select(Address).where(Address.user_id == ctx.user.id)).all()
    if not addrs:
        raise ToolError("The user has no saved address. Ask them to add one in Profile → Addresses first.")
    addr = next((a for a in addrs if a.id == address_id), None) if address_id else addrs[0]
    if not addr:
        raise ToolError("Unknown address_id; call list_my_addresses.")
    if cook.service_pincodes and addr.pincode not in cook.service_pincodes:
        raise ToolError(f"{cook.user.name} doesn't serve pincode {addr.pincode}. Suggest another cook.")
    plan_title = None
    if meal_plan_id:
        plan_title = _plan(ctx, meal_plan_id).title
    q = quote(cook.hourly_rate, int(duration_hours), int(guests))
    payload = {
        "cook_id": cook.user_id, "address_id": addr.id, "service_date": d.isoformat(),
        "start_time": t.strftime("%H:%M:%S"), "duration_hours": int(duration_hours), "meal_type": meal_type,
        "guests": int(guests), "notes": notes, "meal_plan_id": meal_plan_id, "groceries_by": "customer",
    }
    ctx.blocks.append({"type": "booking_draft", "payload": payload, "cook_name": cook.user.name,
                       "address": f"{addr.label} · {addr.area} {addr.pincode}", "meal_plan_title": plan_title,
                       "quote": q.model_dump()})
    return {"status": "draft_shown", "total_inr": q.total,
            "note": "The user must tap Confirm on the card to place the booking. Do not claim it is booked."}


# ================================================================ cook tools
def _my_profile(ctx: ToolContext) -> CookProfile:
    p = ctx.db.get(CookProfile, ctx.user.id)
    if not p:
        raise ToolError("This cook hasn't created a profile yet. Suggest one with suggest_profile_update.")
    return p


def get_my_cook_profile(ctx: ToolContext):
    try:
        p = _my_profile(ctx)
    except ToolError:
        return {"exists": False, "name": ctx.user.name}
    d = _cook_dict(p)
    d["dishes"] = [x.name for x in p.dishes]
    return {"exists": True, **d}


def get_my_jobs(ctx: ToolContext, status: str | None = None):
    q = select(Booking).where(Booking.cook_id == ctx.user.id)
    if status:
        q = q.where(Booking.status == BookingStatus(status))
    jobs = ctx.db.scalars(q.order_by(Booking.service_date)).all()
    return {"jobs": [
        {"id": b.id, "customer": b.customer.name, "date": b.service_date.isoformat(),
         "time": b.start_time.strftime("%H:%M"), "hours": b.duration_hours, "meal_type": b.meal_type.value,
         "guests": b.guests, "status": b.status.value, "notes": b.notes, "area": b.address.area,
         "meal_plan": b.meal_plan.title if b.meal_plan else None}
        for b in jobs[:20]
    ]}


def market_rates(ctx: ToolContext, pincode: str | None = None, cuisine: str | None = None):
    q = select(CookProfile).where(CookProfile.is_active.is_(True), CookProfile.user_id != ctx.user.id)
    if pincode:
        q = q.where(CookProfile.service_pincodes.any(str(pincode)))
    cooks = ctx.db.scalars(q).all()
    if cuisine:
        cooks = [c for c in cooks if any(cuisine.lower() in x.lower() for x in c.cuisines)] or cooks
    if not cooks:
        return {"cooks_compared": 0, "note": "No comparable cooks yet."}
    rates = [c.hourly_rate for c in cooks]
    return {"cooks_compared": len(cooks), "avg_rate": round(mean(rates)), "min_rate": min(rates),
            "max_rate": max(rates), "top_rated_rate": max(cooks, key=lambda c: c.rating_avg).hourly_rate}


def suggest_profile_update(ctx: ToolContext, bio: str | None = None, cuisines: list | None = None,
                           languages: list | None = None, hourly_rate: int | None = None,
                           new_dishes: list | None = None, reason: str = ""):
    changes = {k: v for k, v in {"bio": bio, "cuisines": cuisines, "languages": languages,
                                 "hourly_rate": hourly_rate, "new_dishes": new_dishes}.items() if v}
    if not changes:
        raise ToolError("Provide at least one change.")
    ctx.blocks.append({"type": "profile_suggestion", "changes": changes, "reason": reason})
    return {"status": "suggestion_shown", "note": "The cook can tap Apply on the card. Nothing is changed yet."}


# ================================================================ registry
_S, _I, _B = {"type": "string"}, {"type": "integer"}, {"type": "boolean"}
_DIET = {"type": "string", "enum": ["veg", "egg", "nonveg"]}
_GOAL = {"type": "string", "enum": ["balanced", "weight_loss", "muscle_gain", "diabetic_friendly", "kids", "traditional"]}

MEAL_SCHEMA = _obj({
    "slot": {"type": "string", "enum": ["breakfast", "lunch", "snack", "dinner"]},
    "dish": {"type": "string", "description": "Dish key from find_dishes (preferred)"},
    "name": {"type": "string", "description": "Free-text dish name if no key fits"},
    "servings": {"type": "number", "description": "Portion multiplier, default 1"},
    "kcal": _I, "protein": {"type": "number"}, "carbs": {"type": "number"}, "fat": {"type": "number"},
}, ["slot"])

TOOLS: dict[str, Tool] = {t.name: t for t in [
    Tool("search_cooks", "Find available home cooks. Filter by 6-digit pincode, cuisine, veg-only and max hourly rate (INR).",
         _obj({"pincode": _S, "cuisine": _S, "veg_only": _B, "max_rate": _I, "limit": _I}), search_cooks),
    Tool("get_cook_details", "Full profile and signature dishes of one cook.", _obj({"cook_id": _I}, ["cook_id"]),
         get_cook_details),
    Tool("list_meal_plans", "List ready-made weekly diet charts and the user's saved plans.",
         _obj({"goal": _GOAL, "diet": _DIET}), list_meal_plans),
    Tool("get_meal_plan", "Day-by-day meals of a plan.", _obj({"plan_id": _I}, ["plan_id"]), get_meal_plan),
    Tool("find_dishes", "Search the dish catalogue (with keys and nutrition) to build a custom plan.",
         _obj({"query": _S, "diet": _DIET}), find_dishes),
    Tool("create_meal_plan", "Create and save a custom weekly plan for the user. Prefer dish keys from find_dishes.",
         _obj({"title": _S, "goal": _GOAL, "diet": _DIET, "description": _S, "cuisine": _S, "emoji": _S,
               "days": {"type": "array", "items": _obj({"day": _I, "meals": {"type": "array", "items": MEAL_SCHEMA}},
                                                         ["day", "meals"])}},
              ["title", "days"]), create_meal_plan),
    Tool("plan_nutrition", "Calories and macros per day and daily average for a plan (shows charts).",
         _obj({"plan_id": _I}, ["plan_id"]), plan_nutrition),
    Tool("plan_grocery_list", "Consolidated grocery list for a plan scaled to number of people.",
         _obj({"plan_id": _I, "people": _I}, ["plan_id"]), plan_grocery_list),
    Tool("get_price_quote", "Price estimate (INR) for a cook, hours and guests.",
         _obj({"cook_id": _I, "duration_hours": _I, "guests": _I}, ["cook_id"]), get_price_quote),
    Tool("list_my_addresses", "The user's saved addresses (id, area, pincode).", _obj({}), list_my_addresses),
    Tool("draft_booking", "Prepare a booking for the user to confirm in the app (does NOT book by itself).",
         _obj({"cook_id": _I, "service_date": {"type": "string", "description": "YYYY-MM-DD"},
               "start_time": {"type": "string", "description": "HH:MM 24h"},
               "meal_type": {"type": "string", "enum": [m.value for m in MealType]},
               "duration_hours": _I, "guests": _I, "address_id": _I, "notes": _S, "meal_plan_id": _I},
              ["cook_id", "service_date", "start_time"]), draft_booking),
    Tool("get_my_cook_profile", "The current cook's own profile.", _obj({}), get_my_cook_profile),
    Tool("get_my_jobs", "The current cook's bookings (optionally by status).",
         _obj({"status": {"type": "string", "enum": [s.value for s in BookingStatus]}}), get_my_jobs),
    Tool("market_rates", "Hourly rates of other cooks (overall or by pincode/cuisine) for pricing advice.",
         _obj({"pincode": _S, "cuisine": _S}), market_rates),
    Tool("suggest_profile_update", "Show the cook a suggested profile change (bio, cuisines, languages, rate, dishes) to apply.",
         _obj({"bio": _S, "cuisines": {"type": "array", "items": _S}, "languages": {"type": "array", "items": _S},
               "hourly_rate": _I, "reason": _S,
               "new_dishes": {"type": "array", "items": _obj({"name": _S, "cuisine": _S, "is_veg": _B}, ["name"])}}),
         suggest_profile_update),
]}


def run_tool(ctx: ToolContext, name: str, args: dict) -> dict:
    tool = TOOLS.get(name)
    if not tool:
        return {"error": f"Unknown tool {name}"}
    if name in {"get_my_cook_profile", "get_my_jobs", "market_rates", "suggest_profile_update"} \
            and ctx.user.role != Role.cook:
        return {"error": "This tool is only for cooks."}
    try:
        return tool.fn(ctx, **(args or {}))
    except ToolError as exc:
        return {"error": str(exc)}
    except HTTPException as exc:
        ctx.db.rollback()
        return {"error": str(exc.detail)}
    except (TypeError, ValueError) as exc:  # wrong/missing arguments from the model
        ctx.db.rollback()
        return {"error": f"Bad arguments: {exc}"}
