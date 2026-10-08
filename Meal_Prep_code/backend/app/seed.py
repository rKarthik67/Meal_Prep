"""Seed demo cooks so the app has something to show.  Run:  python -m app.seed"""

from sqlalchemy import select

from .db import Base, SessionLocal, engine
from .models import CookProfile, Dish, Role, User

COOKS = [
    {
        "phone": "+919000000001", "name": "Lakshmi Amma",
        "bio": "Home-style South Indian meals, 12 years cooking for families in Jayanagar.",
        "cuisines": ["South Indian", "Karnataka"], "languages": ["Kannada", "Tamil", "English"],
        "pincodes": ["560041", "560011", "560070"], "veg_only": True, "exp": 12, "rate": 300, "verified": True,
        "dishes": [("Bisi Bele Bath", "Karnataka", True, 60), ("Idli & Sambar", "South Indian", True, 45),
                   ("Ragi Mudde with Saaru", "Karnataka", True, 50)],
    },
    {
        "phone": "+919000000002", "name": "Rajesh Kumar",
        "bio": "North Indian & Mughlai. Weekly meal-prep specialist (5-day batches).",
        "cuisines": ["North Indian", "Mughlai"], "languages": ["Hindi", "English"],
        "pincodes": ["560034", "560095", "560102"], "veg_only": False, "exp": 8, "rate": 350, "verified": True,
        "dishes": [("Dal Makhani", "North Indian", True, 90), ("Chicken Curry", "North Indian", False, 60),
                   ("Rajma Chawal", "North Indian", True, 70)],
    },
    {
        "phone": "+919000000003", "name": "Fathima S",
        "bio": "Kerala & Chettinad flavours, healthy low-oil meal prep.",
        "cuisines": ["Kerala", "Chettinad", "South Indian"], "languages": ["Malayalam", "Tamil", "English"],
        "pincodes": ["560034", "560041", "560068"], "veg_only": False, "exp": 5, "rate": 280, "verified": False,
        "dishes": [("Appam & Veg Stew", "Kerala", True, 60), ("Chettinad Chicken", "Chettinad", False, 75)],
    },
]


def run() -> None:
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        for c in COOKS:
            uid = f"dev-{c['phone']}"
            if db.scalar(select(User).where(User.firebase_uid == uid)):
                continue
            u = User(firebase_uid=uid, phone=c["phone"], name=c["name"], role=Role.cook)
            db.add(u)
            db.flush()
            db.add(CookProfile(
                user_id=u.id, bio=c["bio"], cuisines=c["cuisines"], languages=c["languages"],
                service_pincodes=c["pincodes"], veg_only=c["veg_only"], experience_years=c["exp"],
                hourly_rate=c["rate"], verified=c["verified"],
            ))
            for name, cuisine, veg, mins in c["dishes"]:
                db.add(Dish(cook_id=u.id, name=name, cuisine=cuisine, is_veg=veg, prep_minutes=mins))
        db.commit()
    print(f"Seeded {len(COOKS)} demo cooks (log in as a cook with dev token dev:+91900000000X).")


if __name__ == "__main__":
    run()
