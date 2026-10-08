from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, Field

from .models import BookingStatus, GroceriesBy, MealType, Role


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- users ----------
class UserOut(ORM):
    id: int
    phone: str
    name: str
    email: str | None
    role: Role


class UserUpdate(BaseModel):
    name: str | None = Field(None, max_length=120)
    email: str | None = None
    role: Role | None = None  # customer <-> cook switch during onboarding (admin not allowed)


# ---------- addresses ----------
class AddressIn(BaseModel):
    label: str = "Home"
    line1: str = Field(min_length=3)
    area: str
    city: str = "Bengaluru"
    pincode: str = Field(pattern=r"^\d{6}$")
    lat: float | None = None
    lng: float | None = None


class AddressOut(ORM, AddressIn):
    id: int


# ---------- cooks ----------
class DishIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    cuisine: str = ""
    is_veg: bool = True
    prep_minutes: int = Field(30, ge=5, le=600)


class DishOut(ORM, DishIn):
    id: int


class CookProfileIn(BaseModel):
    bio: str = ""
    cuisines: list[str] = []
    languages: list[str] = []
    service_pincodes: list[str] = []
    veg_only: bool = False
    experience_years: int = Field(0, ge=0, le=60)
    hourly_rate: int = Field(250, ge=100, le=5000)
    is_active: bool = True


class CookOut(ORM):
    user_id: int
    name: str
    bio: str
    cuisines: list[str]
    languages: list[str]
    service_pincodes: list[str]
    veg_only: bool
    experience_years: int
    hourly_rate: int
    rating_avg: float
    rating_count: int
    verified: bool
    is_active: bool


class CookDetail(CookOut):
    dishes: list[DishOut]


# ---------- bookings ----------
class BookingIn(BaseModel):
    cook_id: int
    address_id: int
    service_date: date
    start_time: time
    duration_hours: int = Field(2, ge=1, le=8)
    meal_type: MealType
    guests: int = Field(2, ge=1, le=50)
    dish_ids: list[int] = []
    groceries_by: GroceriesBy = GroceriesBy.customer
    notes: str = ""
    meal_plan_id: int | None = None


class BookingOut(ORM):
    id: int
    customer_id: int
    customer_name: str
    cook_id: int
    cook_name: str
    address: AddressOut
    service_date: date
    start_time: time
    duration_hours: int
    meal_type: MealType
    guests: int
    dish_ids: list[int]
    groceries_by: GroceriesBy
    notes: str
    status: BookingStatus
    price_estimate: int
    created_at: datetime
    rating: int | None = None
    meal_plan_id: int | None = None
    meal_plan_title: str | None = None
    cook_cuisines: list[str] = []


class QuoteOut(BaseModel):
    cook_fee: int
    extra_guest_fee: int
    platform_fee: int
    total: int


class ReviewIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = ""
