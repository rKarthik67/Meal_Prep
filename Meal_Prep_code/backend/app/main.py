from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from . import models  # noqa: F401  (register tables)
from .config import get_settings
from .db import Base, SessionLocal, engine
from .routers import ai, bookings, cooks, meal_plans, stats, users


UPGRADES = [
    # v0.2: bookings can reference a meal plan
    "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS meal_plan_id INTEGER "
    "REFERENCES meal_plans(id) ON DELETE SET NULL",
]


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Create tables, apply small in-place upgrades, refresh curated diet charts.
    # (Move to Alembic migrations before you have real users.)
    Base.metadata.create_all(engine)
    with engine.begin() as conn:
        for ddl in UPGRADES:
            conn.execute(text(ddl))
    with SessionLocal() as db:
        meal_plans.seed_templates(db)
    yield


app = FastAPI(title="Meal Prep API", version="0.2.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(IntegrityError)
async def integrity_error(_: Request, exc: IntegrityError):
    return JSONResponse(status_code=409, content={"detail": "Conflicts with existing data (it may be in use)"})


@app.get("/health", tags=["meta"])
def health():
    with engine.connect() as conn:
        conn.execute(text("select 1"))
    return {"status": "ok", "auth_mode": get_settings().auth_mode}


app.include_router(users.router)
app.include_router(cooks.router)
app.include_router(bookings.router)
app.include_router(meal_plans.router)
app.include_router(stats.router)
app.include_router(ai.router)
