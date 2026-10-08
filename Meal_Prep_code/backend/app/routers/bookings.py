from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from ..auth import current_user, require_role
from ..db import get_db
from ..models import Address, Booking, BookingStatus, CookProfile, Dish, MealPlan, Review, Role, User
from ..pricing import quote
from ..schemas import AddressOut, BookingIn, BookingOut, QuoteOut, ReviewIn

router = APIRouter(prefix="/bookings", tags=["bookings"])

S = BookingStatus
# action -> (who may do it, allowed from-states, resulting state)
TRANSITIONS: dict[str, tuple[str, set[BookingStatus], BookingStatus]] = {
    "accept": ("cook", {S.requested}, S.accepted),
    "reject": ("cook", {S.requested}, S.rejected),
    "start": ("cook", {S.accepted}, S.in_progress),
    "complete": ("cook", {S.in_progress}, S.completed),
    "cancel": ("customer", {S.requested, S.accepted}, S.cancelled),
}


def _out(b: Booking) -> BookingOut:
    return BookingOut(
        id=b.id,
        customer_id=b.customer_id,
        customer_name=b.customer.name,
        cook_id=b.cook_id,
        cook_name=b.cook.user.name,
        address=AddressOut.model_validate(b.address),
        service_date=b.service_date,
        start_time=b.start_time,
        duration_hours=b.duration_hours,
        meal_type=b.meal_type,
        guests=b.guests,
        dish_ids=b.dish_ids,
        groceries_by=b.groceries_by,
        notes=b.notes,
        status=b.status,
        price_estimate=b.price_estimate,
        created_at=b.created_at,
        rating=b.review.rating if b.review else None,
        meal_plan_id=b.meal_plan_id,
        meal_plan_title=b.meal_plan.title if b.meal_plan else None,
        cook_cuisines=b.cook.cuisines or [],
    )


def _get_owned(db: Session, booking_id: int, user: User) -> Booking:
    b = db.get(Booking, booking_id)
    if not b or user.id not in (b.customer_id, b.cook_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Booking not found")
    return b


@router.get("/quote", response_model=QuoteOut)
def get_quote(
    cook_id: int,
    duration_hours: int = Query(2, ge=1, le=8),
    guests: int = Query(2, ge=1, le=50),
    _: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    cook = db.get(CookProfile, cook_id)
    if not cook:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cook not found")
    return quote(cook.hourly_rate, duration_hours, guests)


@router.post("", response_model=BookingOut, status_code=201)
def create_booking(
    body: BookingIn, user: User = Depends(require_role(Role.customer)), db: Session = Depends(get_db)
):
    if body.service_date < date.today():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Service date is in the past")

    cook = db.get(CookProfile, body.cook_id)
    if not cook or not cook.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cook not available")

    addr = db.get(Address, body.address_id)
    if not addr or addr.user_id != user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid address")
    if cook.service_pincodes and addr.pincode not in cook.service_pincodes:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cook does not serve this pincode")

    if body.dish_ids:
        n = db.scalar(select(func.count()).where(Dish.id.in_(body.dish_ids), Dish.cook_id == cook.user_id))
        if n != len(set(body.dish_ids)):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Some dishes are not offered by this cook")

    # Simple double-booking guard: cook can't have two active bookings on the same date+time.
    clash = db.scalar(
        select(Booking.id).where(
            Booking.cook_id == cook.user_id,
            Booking.service_date == body.service_date,
            Booking.start_time == body.start_time,
            Booking.status.in_([S.requested, S.accepted, S.in_progress]),
        )
    )
    if clash:
        raise HTTPException(status.HTTP_409_CONFLICT, "Cook already has a booking at that time")

    if body.meal_plan_id is not None:
        plan = db.get(MealPlan, body.meal_plan_id)
        if not plan or (plan.owner_id is not None and plan.owner_id != user.id):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid meal plan")

    price = quote(cook.hourly_rate, body.duration_hours, body.guests).total
    b = Booking(customer_id=user.id, price_estimate=price, **body.model_dump())
    db.add(b)
    db.commit()
    db.refresh(b)
    return _out(b)


@router.get("", response_model=list[BookingOut])
def list_bookings(
    status_filter: BookingStatus | None = Query(None, alias="status"),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    q = select(Booking).where(or_(Booking.customer_id == user.id, Booking.cook_id == user.id))
    if status_filter:
        q = q.where(Booking.status == status_filter)
    q = q.order_by(Booking.service_date.desc(), Booking.start_time.desc())
    return [_out(b) for b in db.scalars(q).all()]


@router.get("/{booking_id}", response_model=BookingOut)
def get_booking(booking_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return _out(_get_owned(db, booking_id, user))


def transition(booking_id: int, action: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if action not in TRANSITIONS:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown action")
    who, from_states, to_state = TRANSITIONS[action]
    b = _get_owned(db, booking_id, user)
    actor_id = b.cook_id if who == "cook" else b.customer_id
    if user.id != actor_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, f"Only the {who} can {action} this booking")
    if b.status not in from_states:
        raise HTTPException(status.HTTP_409_CONFLICT, f"Cannot {action} a booking that is {b.status.value}")
    b.status = to_state
    db.commit()
    db.refresh(b)
    return _out(b)


@router.post("/{booking_id}/review", response_model=BookingOut, status_code=201)
def review(booking_id: int, body: ReviewIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    b = _get_owned(db, booking_id, user)
    if user.id != b.customer_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the customer can review")
    if b.status != S.completed:
        raise HTTPException(status.HTTP_409_CONFLICT, "Can only review completed bookings")
    if b.review:
        raise HTTPException(status.HTTP_409_CONFLICT, "Already reviewed")

    db.add(Review(booking_id=b.id, rating=body.rating, comment=body.comment))
    cook = b.cook
    cook.rating_avg = round((cook.rating_avg * cook.rating_count + body.rating) / (cook.rating_count + 1), 2)
    cook.rating_count += 1
    db.commit()
    db.refresh(b)
    return _out(b)


# Registered last so /{id}/review above takes precedence.
router.post("/{booking_id}/{action}", response_model=BookingOut)(transition)
