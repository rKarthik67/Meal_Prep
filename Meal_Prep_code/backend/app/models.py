import enum
from datetime import date, datetime, time

from sqlalchemy import (
    ARRAY,
    JSON,
    Boolean,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


class Role(str, enum.Enum):
    customer = "customer"
    cook = "cook"
    admin = "admin"


class MealType(str, enum.Enum):
    breakfast = "breakfast"
    lunch = "lunch"
    dinner = "dinner"
    meal_prep = "meal_prep"  # batch-cook several days of meals in one visit
    party = "party"


class GroceriesBy(str, enum.Enum):
    customer = "customer"
    cook = "cook"


class BookingStatus(str, enum.Enum):
    requested = "requested"
    accepted = "accepted"
    rejected = "rejected"
    cancelled = "cancelled"
    in_progress = "in_progress"
    completed = "completed"


def _enum(e):
    return Enum(e, name=e.__name__.lower(), values_callable=lambda x: [m.value for m in x])


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    phone: Mapped[str] = mapped_column(String(20), index=True)
    name: Mapped[str] = mapped_column(String(120), default="")
    email: Mapped[str | None] = mapped_column(String(200))
    role: Mapped[Role] = mapped_column(_enum(Role), default=Role.customer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    addresses: Mapped[list["Address"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    cook_profile: Mapped["CookProfile | None"] = relationship(back_populates="user", uselist=False)


class Address(Base):
    __tablename__ = "addresses"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    label: Mapped[str] = mapped_column(String(40), default="Home")
    line1: Mapped[str] = mapped_column(String(255))
    area: Mapped[str] = mapped_column(String(120))
    city: Mapped[str] = mapped_column(String(80), default="Bengaluru")
    pincode: Mapped[str] = mapped_column(String(10), index=True)
    lat: Mapped[float | None] = mapped_column(Float)
    lng: Mapped[float | None] = mapped_column(Float)

    user: Mapped[User] = relationship(back_populates="addresses")


class CookProfile(Base):
    __tablename__ = "cook_profiles"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    bio: Mapped[str] = mapped_column(Text, default="")
    cuisines: Mapped[list[str]] = mapped_column(ARRAY(String(40)), default=list)
    languages: Mapped[list[str]] = mapped_column(ARRAY(String(30)), default=list)
    service_pincodes: Mapped[list[str]] = mapped_column(ARRAY(String(10)), default=list)
    veg_only: Mapped[bool] = mapped_column(Boolean, default=False)
    experience_years: Mapped[int] = mapped_column(Integer, default=0)
    hourly_rate: Mapped[int] = mapped_column(Integer, default=250)  # INR
    rating_avg: Mapped[float] = mapped_column(Float, default=0.0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)  # KYC / background check done
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    user: Mapped[User] = relationship(back_populates="cook_profile")
    dishes: Mapped[list["Dish"]] = relationship(back_populates="cook", cascade="all, delete-orphan")


class Dish(Base):
    __tablename__ = "dishes"

    id: Mapped[int] = mapped_column(primary_key=True)
    cook_id: Mapped[int] = mapped_column(ForeignKey("cook_profiles.user_id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    cuisine: Mapped[str] = mapped_column(String(40), default="")
    is_veg: Mapped[bool] = mapped_column(Boolean, default=True)
    prep_minutes: Mapped[int] = mapped_column(Integer, default=30)

    cook: Mapped[CookProfile] = relationship(back_populates="dishes")


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    cook_id: Mapped[int] = mapped_column(ForeignKey("cook_profiles.user_id"), index=True)
    address_id: Mapped[int] = mapped_column(ForeignKey("addresses.id"))
    service_date: Mapped[date] = mapped_column(Date, index=True)
    start_time: Mapped[time] = mapped_column(Time)
    duration_hours: Mapped[int] = mapped_column(Integer, default=2)
    meal_type: Mapped[MealType] = mapped_column(_enum(MealType))
    guests: Mapped[int] = mapped_column(Integer, default=2)
    dish_ids: Mapped[list[int]] = mapped_column(ARRAY(Integer), default=list)
    groceries_by: Mapped[GroceriesBy] = mapped_column(_enum(GroceriesBy), default=GroceriesBy.customer)
    notes: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[BookingStatus] = mapped_column(_enum(BookingStatus), default=BookingStatus.requested, index=True)
    price_estimate: Mapped[int] = mapped_column(Integer)  # INR, incl. platform fee
    meal_plan_id: Mapped[int | None] = mapped_column(ForeignKey("meal_plans.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    customer: Mapped[User] = relationship(foreign_keys=[customer_id])
    cook: Mapped[CookProfile] = relationship(foreign_keys=[cook_id])
    address: Mapped[Address] = relationship()
    review: Mapped["Review | None"] = relationship(back_populates="booking", uselist=False)
    meal_plan: Mapped["MealPlan | None"] = relationship()


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("booking_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id", ondelete="CASCADE"))
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    booking: Mapped[Booking] = relationship(back_populates="review")


class MealPlan(Base):
    """A weekly diet chart. Templates (owner_id NULL) are curated; users and AI agents can save their own."""

    __tablename__ = "meal_plans"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    slug: Mapped[str | None] = mapped_column(String(80), unique=True)
    title: Mapped[str] = mapped_column(String(120))
    subtitle: Mapped[str] = mapped_column(String(200), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    goal: Mapped[str] = mapped_column(String(40), default="balanced", index=True)
    diet: Mapped[str] = mapped_column(String(10), default="veg")  # veg | egg | nonveg
    cuisine: Mapped[str] = mapped_column(String(40), default="Mixed")
    emoji: Mapped[str] = mapped_column(String(16), default="🍛")
    color: Mapped[str] = mapped_column(String(9), default="#E8772E")
    tags: Mapped[list[str]] = mapped_column(ARRAY(String(40)), default=list)
    days: Mapped[list] = mapped_column(JSON().with_variant(JSONB, "postgresql"), default=list)
    created_by_ai: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AIConversation(Base):
    __tablename__ = "ai_conversations"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    agent: Mapped[str] = mapped_column(String(30))
    title: Mapped[str] = mapped_column(String(120), default="New chat")
    # [{role: user|assistant, content: str, blocks?: [...]}]
    messages: Mapped[list] = mapped_column(JSON().with_variant(JSONB, "postgresql"), default=list)
    provider: Mapped[str] = mapped_column(String(20), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
