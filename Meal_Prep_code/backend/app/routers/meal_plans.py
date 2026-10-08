from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..foods import FOODS, search_foods
from ..models import MealPlan, User
from ..plans import GOALS, SLOTS, TEMPLATES, grocery_list, nutrition_summary, resolve_days

router = APIRouter(tags=["meal plans"])


# ---------------------------------------------------------------- helpers (also used by AI tools)
def plan_summary(p: MealPlan) -> dict:
    n = nutrition_summary(p.days)
    return {
        "id": p.id, "title": p.title, "subtitle": p.subtitle, "emoji": p.emoji, "color": p.color,
        "goal": p.goal, "goal_label": GOALS.get(p.goal, p.goal.replace("_", " ").title()),
        "diet": p.diet, "cuisine": p.cuisine, "tags": p.tags or [],
        "is_template": p.owner_id is None, "created_by_ai": p.created_by_ai,
        "days_count": len(p.days),
        "avg_kcal": n["daily_average"]["kcal"], "avg_protein": n["daily_average"]["protein"],
    }


def plan_detail(p: MealPlan) -> dict:
    return {**plan_summary(p), "description": p.description, "days": resolve_days(p.days),
            "nutrition": nutrition_summary(p.days)}


def visible_plans_query(user: User):
    return select(MealPlan).where(or_(MealPlan.owner_id.is_(None), MealPlan.owner_id == user.id))


def get_visible_plan(db: Session, plan_id: int, user: User) -> MealPlan:
    p = db.get(MealPlan, plan_id)
    if not p or (p.owner_id is not None and p.owner_id != user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Meal plan not found")
    return p


def seed_templates(db: Session) -> None:
    """Insert or refresh the curated diet charts (idempotent)."""
    for t in TEMPLATES:
        p = db.scalar(select(MealPlan).where(MealPlan.slug == t["slug"])) or MealPlan(slug=t["slug"])
        for k, v in t.items():
            setattr(p, k, v)
        db.add(p)
    db.commit()


# ---------------------------------------------------------------- schemas
class MealIn(BaseModel):
    slot: str = Field(pattern="^(breakfast|lunch|snack|dinner)$")
    dish: str | None = None  # key from /foods
    name: str | None = None  # free-text dish (nutrition estimated)
    servings: float = Field(1, gt=0, le=5)
    kcal: int | None = None
    protein: float | None = None
    carbs: float | None = None
    fat: float | None = None


class DayIn(BaseModel):
    day: int = Field(ge=1, le=14)
    meals: list[MealIn] = Field(min_length=1, max_length=6)


class MealPlanIn(BaseModel):
    title: str = Field(min_length=3, max_length=120)
    subtitle: str = ""
    description: str = ""
    goal: str = "balanced"
    diet: str = Field("veg", pattern="^(veg|egg|nonveg)$")
    cuisine: str = "Mixed"
    emoji: str = "🍽️"
    color: str = "#E8772E"
    tags: list[str] = []
    days: list[DayIn] = Field(min_length=1, max_length=14)


def create_plan(db: Session, user: User, body: MealPlanIn, by_ai: bool = False) -> MealPlan:
    days = []
    for d in body.days:
        meals = []
        for m in d.meals:
            if m.dish and m.dish not in FOODS:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Unknown dish key: {m.dish}")
            meals.append({k: v for k, v in m.model_dump().items() if v is not None and not (k == "servings" and v == 1)})
        days.append({"day": d.day, "meals": sorted(meals, key=lambda x: SLOTS.index(x["slot"]))})
    p = MealPlan(owner_id=user.id, created_by_ai=by_ai, **body.model_dump(exclude={"days"}), days=days)
    db.add(p)
    db.commit()
    db.refresh(p)
    return p


# ---------------------------------------------------------------- routes
@router.get("/meal-plans")
def list_plans(
    goal: str | None = None,
    diet: str | None = Query(None, pattern="^(veg|egg|nonveg)$"),
    mine: bool = False,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    q = select(MealPlan).where(MealPlan.owner_id == user.id) if mine else visible_plans_query(user)
    if goal:
        q = q.where(MealPlan.goal == goal)
    if diet:
        q = q.where(MealPlan.diet == diet)
    q = q.order_by(MealPlan.owner_id.is_(None), MealPlan.id)  # user's own plans first
    return [plan_summary(p) for p in db.scalars(q).all()]


@router.get("/meal-plans/goals")
def goals():
    return [{"key": k, "label": v} for k, v in GOALS.items()]


@router.get("/meal-plans/{plan_id}")
def get_plan(plan_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return plan_detail(get_visible_plan(db, plan_id, user))


@router.get("/meal-plans/{plan_id}/grocery")
def get_grocery(
    plan_id: int,
    people: int = Query(2, ge=1, le=30),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    p = get_visible_plan(db, plan_id, user)
    return {"plan_id": p.id, "people": people, "categories": grocery_list(p.days, people)}


@router.post("/meal-plans", status_code=201)
def save_plan(body: MealPlanIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return plan_detail(create_plan(db, user, body))


@router.delete("/meal-plans/{plan_id}", status_code=204)
def delete_plan(plan_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    p = db.get(MealPlan, plan_id)
    if not p or p.owner_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Meal plan not found")
    db.delete(p)
    db.commit()


@router.get("/foods")
def foods(q: str = "", diet: str | None = None, _: User = Depends(current_user)):
    return [
        {"key": f.key, "name": f.name, "emoji": f.emoji, "cuisine": f.cuisine, "diet": f.diet, **f.macros()}
        for f in search_foods(q, diet, limit=100)
    ]
