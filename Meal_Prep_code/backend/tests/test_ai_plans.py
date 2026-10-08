"""Meal plans, insights and the AI agents (offline mock provider + provider adapters with fake clients)."""

import os
from datetime import date, timedelta
from types import SimpleNamespace as NS

os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+psycopg://localhost:5432/meal_prep_test"
)
os.environ["AUTH_MODE"] = "dev"
os.environ["AI_PROVIDER"] = "mock"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.ai.providers import AnthropicProvider, OpenAICompatProvider, ToolCall  # noqa: E402
from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.seed import run as seed_cooks  # noqa: E402

CUST = {"Authorization": "Bearer dev:+919833333333"}
COOK = {"Authorization": "Bearer dev:+919000000001"}  # seeded "Lakshmi Amma"


@pytest.fixture(scope="module")
def client():
    Base.metadata.drop_all(engine)
    with TestClient(app) as c:
        seed_cooks()
        c.patch("/me", json={"name": "Priya"}, headers=CUST)
        c.post("/me/addresses", headers=CUST, json={"line1": "4 Temple Rd", "area": "Jayanagar", "pincode": "560041"})
        yield c
    Base.metadata.drop_all(engine)


def test_meal_plans_and_grocery(client):
    plans = client.get("/meal-plans", headers=CUST).json()
    assert len(plans) == 10 and all(p["is_template"] for p in plans)
    hp = next(p for p in plans if p["goal"] == "muscle_gain")
    assert hp["avg_protein"] > 100

    detail = client.get(f"/meal-plans/{hp['id']}", headers=CUST).json()
    assert len(detail["days"]) == 7 and len(detail["days"][0]["meals"]) == 4
    assert detail["nutrition"]["macro_split_pct"]["protein"] > 20

    g = client.get(f"/meal-plans/{hp['id']}/grocery?people=3", headers=CUST).json()
    cats = {c["category"] for c in g["categories"]}
    assert "Meat & Seafood" in cats and "Vegetables" in cats

    assert len(client.get("/meal-plans?diet=veg&goal=weight_loss", headers=CUST).json()) == 1
    assert client.get("/foods?q=dosa", headers=CUST).json()[0]["key"] in ("masala_dosa", "ragi_dosa")

    custom = client.post("/meal-plans", headers=CUST, json={
        "title": "My week", "days": [{"day": 1, "meals": [
            {"slot": "dinner", "dish": "rasam_rice"}, {"slot": "breakfast", "name": "Paneer sandwich", "kcal": 350}]}]})
    assert custom.status_code == 201, custom.text
    assert custom.json()["days"][0]["meals"][0]["slot"] == "breakfast"  # sorted by slot
    assert client.post("/meal-plans", headers=CUST, json={
        "title": "Bad", "days": [{"day": 1, "meals": [{"slot": "lunch", "dish": "nope"}]}]}).status_code == 400
    assert client.get("/meal-plans?mine=true", headers=CUST).json()[0]["title"] == "My week"
    # other users can't see it
    assert client.get(f"/meal-plans/{custom.json()['id']}", headers=COOK).status_code == 404


def test_agents_listing(client):
    cust = client.get("/ai/agents", headers=CUST).json()
    assert {a["key"] for a in cust["agents"]} == {"meal_planner", "cook_matcher", "nutrition_coach"}
    assert cust["default_provider"] == "mock"
    cook = client.get("/ai/agents", headers=COOK).json()
    assert [a["key"] for a in cook["agents"]] == ["cook_assistant"]
    # customers can't use the cook agent
    assert client.post("/ai/chat", headers=CUST, json={"agent": "cook_assistant", "message": "hi"}).status_code == 404


def test_meal_planner_flow(client):
    r = client.post("/ai/chat", headers=CUST, json={"agent": "meal_planner", "message": "Plan a high protein week"}).json()
    assert r["blocks"][0]["type"] == "meal_plans" and r["blocks"][0]["plans"][0]["goal"] == "muscle_gain"
    assert "plan #" in r["reply"] and r["suggestions"]
    cid = r["conversation_id"]

    r2 = client.post("/ai/chat", headers=CUST, json={
        "agent": "meal_planner", "conversation_id": cid, "message": "grocery list for 3 people"}).json()
    g = r2["blocks"][0]
    assert g["type"] == "grocery_list" and g["people"] == 3 and g["plan_id"] == r["blocks"][0]["plans"][0]["id"]

    r3 = client.post("/ai/chat", headers=CUST, json={
        "agent": "meal_planner", "conversation_id": cid, "message": "show nutrition"}).json()
    assert r3["blocks"][0]["type"] == "nutrition"

    convs = client.get("/ai/conversations", headers=CUST).json()
    assert convs[0]["id"] == cid
    full = client.get(f"/ai/conversations/{cid}", headers=CUST).json()
    assert len(full["messages"]) == 6


def test_cook_matcher_drafts_then_user_confirms(client):
    r = client.post("/ai/chat", headers=CUST, json={
        "agent": "cook_matcher", "message": "Book a south indian cook tomorrow 9am for 3 people"}).json()
    draft = next(b for b in r["blocks"] if b["type"] == "booking_draft")
    p = draft["payload"]
    assert p["start_time"] == "09:00:00" and p["guests"] == 3
    assert p["service_date"] == (date.today() + timedelta(days=1)).isoformat()
    assert "Confirm" in r["reply"]
    # nothing booked until the user confirms
    assert client.get("/bookings", headers=CUST).json() == []
    b = client.post("/bookings", headers=CUST, json=p)
    assert b.status_code == 201, b.text


def test_cook_assistant_and_stats(client):
    r = client.post("/ai/chat", headers=COOK, json={"agent": "cook_assistant", "message": "Write a better bio"}).json()
    sug = r["blocks"][0]
    assert sug["type"] == "profile_suggestion" and "years" in sug["changes"]["bio"]
    r = client.post("/ai/chat", headers=COOK, json={"agent": "cook_assistant", "message": "is my rate right?"}).json()
    assert "₹" in r["reply"]

    s = client.get("/me/stats", headers=CUST).json()
    assert len(s["monthly"]) == 6 and s["upcoming"] == 1
    s = client.get("/me/stats", headers=COOK).json()
    assert s["role"] == "cook" and s["pending_requests"] == 1


def test_provider_unavailable_is_503(client):
    r = client.post("/ai/chat", headers=CUST, json={"agent": "meal_planner", "message": "hi", "provider": "azure"})
    assert r.status_code == 503 and "not configured" in r.json()["detail"]


# ---------------------------------------------------------------- provider adapters
HISTORY = [
    {"role": "user", "content": "find cooks"},
    {"role": "assistant", "content": "", "tool_calls": [ToolCall("t1", "search_cooks", {"pincode": "560041"}),
                                                        ToolCall("t2", "list_my_addresses", {})]},
    {"role": "tool", "tool_call_id": "t1", "name": "search_cooks", "content": '{"count": 1}'},
    {"role": "tool", "tool_call_id": "t2", "name": "list_my_addresses", "content": '{"addresses": []}'},
]
TOOLS = [{"name": "search_cooks", "description": "d", "parameters": {"type": "object", "properties": {}}}]


def test_openai_adapter():
    seen = {}

    def create(**kw):
        seen.update(kw)
        msg = NS(content=None, tool_calls=[NS(id="c1", function=NS(name="search_cooks", arguments='{"pincode":"1"}'))])
        return NS(choices=[NS(message=msg)])

    client = NS(chat=NS(completions=NS(create=create)))
    out = OpenAICompatProvider(client, "dep", "azure", "Azure").chat("sys", HISTORY, TOOLS)
    assert out.tool_calls[0].arguments == {"pincode": "1"}
    m = seen["messages"]
    assert m[0]["role"] == "system" and m[2]["tool_calls"][1]["function"]["name"] == "list_my_addresses"
    assert m[3] == {"role": "tool", "tool_call_id": "t1", "content": '{"count": 1}'}
    assert seen["tools"][0]["type"] == "function"


def test_anthropic_adapter():
    seen = {}

    def create(**kw):
        seen.update(kw)
        return NS(content=[NS(type="text", text="Here you go"),
                           NS(type="tool_use", id="u1", name="search_cooks", input={"cuisine": "Kerala"})])

    out = AnthropicProvider(NS(messages=NS(create=create)), "claude").chat("sys", HISTORY, TOOLS)
    assert out.text == "Here you go" and out.tool_calls[0].arguments == {"cuisine": "Kerala"}
    msgs = seen["messages"]
    assert seen["system"] == "sys" and len(msgs) == 3  # parallel tool results grouped in one user turn
    assert [b["type"] for b in msgs[1]["content"]] == ["tool_use", "tool_use"]
    assert [b["tool_use_id"] for b in msgs[2]["content"]] == ["t1", "t2"]
    assert seen["tools"][0]["input_schema"]["type"] == "object"
