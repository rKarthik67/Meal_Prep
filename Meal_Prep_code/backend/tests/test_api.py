"""End-to-end API tests against a real Postgres (TEST_DATABASE_URL, default meal_prep_test)."""

import os
from datetime import date, timedelta

os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+psycopg://localhost:5432/meal_prep_test"
)
os.environ["AUTH_MODE"] = "dev"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402

CUST = {"Authorization": "Bearer dev:+919811111111"}
COOK = {"Authorization": "Bearer dev:+919822222222"}


@pytest.fixture(scope="module")
def client():
    Base.metadata.drop_all(engine)
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(engine)


def test_full_flow(client):
    assert client.get("/health").json()["status"] == "ok"
    assert client.get("/me").status_code == 401

    # cook onboarding
    assert client.patch("/me", json={"name": "Meena", "role": "cook"}, headers=COOK).json()["role"] == "cook"
    r = client.put("/cooks/me", headers=COOK, json={
        "bio": "Andhra meals", "cuisines": ["Andhra"], "languages": ["Telugu"],
        "service_pincodes": ["560034"], "hourly_rate": 300})
    assert r.status_code == 200, r.text
    cook_id = r.json()["user_id"]
    dish = client.post("/cooks/me/dishes", headers=COOK, json={"name": "Pesarattu", "cuisine": "Andhra"}).json()

    # customer onboarding
    assert client.patch("/me", json={"role": "admin"}, headers=CUST).status_code == 403
    client.patch("/me", json={"name": "Karthik"}, headers=CUST)
    addr = client.post("/me/addresses", headers=CUST, json={
        "line1": "12, 5th Cross", "area": "Koramangala", "pincode": "560034"}).json()
    far = client.post("/me/addresses", headers=CUST, json={
        "line1": "1 MG Road", "area": "MG Road", "pincode": "560001"}).json()

    # search
    assert [c["user_id"] for c in client.get("/cooks?pincode=560034", headers=CUST).json()] == [cook_id]
    assert client.get("/cooks?pincode=560001", headers=CUST).json() == []
    assert client.get(f"/cooks/{cook_id}", headers=CUST).json()["dishes"][0]["name"] == "Pesarattu"

    # quote: 300*3=900, 2 extra guests*50=100, 10% fee=100 -> 1100
    q = client.get(f"/bookings/quote?cook_id={cook_id}&duration_hours=3&guests=6", headers=CUST).json()
    assert q["total"] == 1100

    day = (date.today() + timedelta(days=2)).isoformat()
    body = {"cook_id": cook_id, "address_id": addr["id"], "service_date": day, "start_time": "08:00:00",
            "duration_hours": 3, "meal_type": "meal_prep", "guests": 6, "dish_ids": [dish["id"]]}
    assert client.post("/bookings", headers=COOK, json=body).status_code == 403  # cooks can't book
    assert client.post("/bookings", headers=CUST, json={**body, "address_id": far["id"]}).status_code == 400
    b = client.post("/bookings", headers=CUST, json=body)
    assert b.status_code == 201, b.text
    b = b.json()
    assert b["price_estimate"] == 1100 and b["status"] == "requested" and b["cook_name"] == "Meena"
    assert client.post("/bookings", headers=CUST, json=body).status_code == 409  # clash

    # address in use can't be deleted
    assert client.delete(f"/me/addresses/{addr['id']}", headers=CUST).status_code == 409

    # state machine
    bid = b["id"]
    assert client.post(f"/bookings/{bid}/accept", headers=CUST).status_code == 403
    assert client.post(f"/bookings/{bid}/complete", headers=COOK).status_code == 409
    for action, expected in [("accept", "accepted"), ("start", "in_progress"), ("complete", "completed")]:
        r = client.post(f"/bookings/{bid}/{action}", headers=COOK)
        assert r.json()["status"] == expected, r.text
    assert client.post(f"/bookings/{bid}/cancel", headers=CUST).status_code == 409

    # review
    assert client.post(f"/bookings/{bid}/review", headers=COOK, json={"rating": 5}).status_code == 403
    r = client.post(f"/bookings/{bid}/review", headers=CUST, json={"rating": 4, "comment": "Tasty"})
    assert r.status_code == 201 and r.json()["rating"] == 4
    assert client.post(f"/bookings/{bid}/review", headers=CUST, json={"rating": 5}).status_code == 409
    cook = client.get(f"/cooks/{cook_id}", headers=CUST).json()
    assert cook["rating_avg"] == 4.0 and cook["rating_count"] == 1

    # both sides see it
    assert len(client.get("/bookings", headers=CUST).json()) == 1
    assert len(client.get("/bookings?status=completed", headers=COOK).json()) == 1
