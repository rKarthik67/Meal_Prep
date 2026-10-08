from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..auth import current_user, require_role
from ..db import get_db
from ..models import CookProfile, Dish, Role, User
from ..schemas import CookDetail, CookOut, CookProfileIn, DishIn, DishOut

router = APIRouter(prefix="/cooks", tags=["cooks"])


def _cook_out(p: CookProfile, detail: bool = False):
    data = {c: getattr(p, c) for c in CookOut.model_fields if c != "name"}
    data["name"] = p.user.name
    if detail:
        data["dishes"] = [DishOut.model_validate(d) for d in p.dishes]
        return CookDetail(**data)
    return CookOut(**data)


@router.get("", response_model=list[CookOut])
def search_cooks(
    pincode: str | None = Query(None, pattern=r"^\d{6}$"),
    cuisine: str | None = None,
    veg_only: bool | None = None,
    max_rate: int | None = None,
    _: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    q = select(CookProfile).options(selectinload(CookProfile.user)).where(CookProfile.is_active.is_(True))
    if pincode:
        q = q.where(CookProfile.service_pincodes.any(pincode))
    if cuisine:
        q = q.where(CookProfile.cuisines.any(cuisine))
    if veg_only:
        q = q.where(CookProfile.veg_only.is_(True))
    if max_rate:
        q = q.where(CookProfile.hourly_rate <= max_rate)
    q = q.order_by(CookProfile.verified.desc(), CookProfile.rating_avg.desc(), CookProfile.rating_count.desc())
    return [_cook_out(p) for p in db.scalars(q).all()]


@router.get("/me", response_model=CookDetail)
def my_cook_profile(user: User = Depends(require_role(Role.cook)), db: Session = Depends(get_db)):
    p = db.get(CookProfile, user.id)
    if not p:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cook profile not created yet")
    return _cook_out(p, detail=True)


@router.put("/me", response_model=CookDetail)
def upsert_cook_profile(
    body: CookProfileIn, user: User = Depends(require_role(Role.cook)), db: Session = Depends(get_db)
):
    p = db.get(CookProfile, user.id) or CookProfile(user_id=user.id)
    for field, value in body.model_dump().items():
        setattr(p, field, value)
    db.add(p)
    db.commit()
    db.refresh(p)
    return _cook_out(p, detail=True)


@router.post("/me/dishes", response_model=DishOut, status_code=201)
def add_dish(body: DishIn, user: User = Depends(require_role(Role.cook)), db: Session = Depends(get_db)):
    if not db.get(CookProfile, user.id):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Create your cook profile first")
    dish = Dish(cook_id=user.id, **body.model_dump())
    db.add(dish)
    db.commit()
    db.refresh(dish)
    return dish


@router.delete("/me/dishes/{dish_id}", status_code=204)
def delete_dish(dish_id: int, user: User = Depends(require_role(Role.cook)), db: Session = Depends(get_db)):
    dish = db.get(Dish, dish_id)
    if not dish or dish.cook_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Dish not found")
    db.delete(dish)
    db.commit()


@router.get("/{cook_id}", response_model=CookDetail)
def get_cook(cook_id: int, _: User = Depends(current_user), db: Session = Depends(get_db)):
    p = db.get(CookProfile, cook_id)
    if not p:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cook not found")
    return _cook_out(p, detail=True)
