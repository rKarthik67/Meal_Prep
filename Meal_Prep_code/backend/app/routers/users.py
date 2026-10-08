from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user
from ..db import get_db
from ..models import Address, Role, User
from ..schemas import AddressIn, AddressOut, UserOut, UserUpdate

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user


@router.patch("", response_model=UserOut)
def update_me(body: UserUpdate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if body.role == Role.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Cannot self-assign admin")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/addresses", response_model=list[AddressOut])
def list_addresses(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Address).where(Address.user_id == user.id).order_by(Address.id)).all()


@router.post("/addresses", response_model=AddressOut, status_code=201)
def add_address(body: AddressIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    addr = Address(user_id=user.id, **body.model_dump())
    db.add(addr)
    db.commit()
    db.refresh(addr)
    return addr


@router.delete("/addresses/{address_id}", status_code=204)
def delete_address(address_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    addr = db.get(Address, address_id)
    if not addr or addr.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")
    db.delete(addr)
    db.commit()
