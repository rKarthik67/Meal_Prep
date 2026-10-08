"""Offline 'demo' provider: a rule-based stand-in for an LLM.

It understands simple intents, calls the same tools a real model would, and writes short replies,
so the whole AI experience (cards, drafts, charts) works with no API keys. Swap AI_PROVIDER to
azure / anthropic / ollama for real conversations.
"""

from __future__ import annotations

import json
import re
import uuid
from datetime import date, timedelta

from .providers import LLMResponse, Provider, ToolCall

CUISINES = ["south indian", "north indian", "kerala", "karnataka", "chettinad", "andhra", "mughlai", "bengali",
            "gujarati", "hyderabadi", "jain"]
WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]


def _call(name: str, **args) -> LLMResponse:
    return LLMResponse(tool_calls=[ToolCall(id=f"mock_{uuid.uuid4().hex[:8]}", name=name,
                                            arguments={k: v for k, v in args.items() if v is not None})])


def _goal(t: str) -> str | None:
    for words, goal in [(("weight", "loss", "lean", "slim", "calorie"), "weight_loss"),
                        (("protein", "gym", "muscle", "fitness"), "muscle_gain"),
                        (("diabet", "sugar", "low-gi", "low gi", "millet"), "diabetic_friendly"),
                        (("kid", "tiffin", "lunchbox", "children"), "kids")]:
        if any(w in t for w in words):
            return goal
    return None


def _diet(t: str) -> str | None:
    if any(w in t for w in ("non-veg", "nonveg", "non veg", "chicken", "fish", "mutton")):
        return "nonveg"
    if "egg" in t:
        return "egg"
    if "veg" in t or "jain" in t:
        return "veg"
    return None


def _date(t: str, today: date) -> date:
    if "today" in t:
        return today
    if "day after" in t:
        return today + timedelta(days=2)
    for i, wd in enumerate(WEEKDAYS):
        if wd in t or wd[:3] + " " in t:
            delta = (i - today.weekday()) % 7 or 7
            return today + timedelta(days=delta)
    return today + timedelta(days=1)


def _time(t: str) -> str:
    m = re.search(r"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b", t)
    if m:
        h = int(m.group(1)) % 12 + (12 if m.group(3) == "pm" else 0)
        return f"{h:02d}:{m.group(2) or '00'}"
    if "dinner" in t or "evening" in t:
        return "18:00"
    if "lunch" in t:
        return "11:00"
    return "08:00"


def _meal_type(t: str) -> str:
    for k in ("breakfast", "lunch", "dinner", "party"):
        if k in t:
            return k
    return "meal_prep" if ("week" in t or "prep" in t) else "lunch"


class MockProvider(Provider):
    name, label = "mock", "Demo (offline)"

    def chat(self, system, messages, tools):
        names = {t["name"] for t in tools}
        today = date.fromisoformat(re.search(r"Today is (\d{4}-\d{2}-\d{2})", system).group(1))
        pins = re.findall(r"\b\d{6}\b", system.split("saved pincodes:")[-1].split("\n")[0])
        last_user_idx = max(i for i, m in enumerate(messages) if m["role"] == "user")
        user_text = messages[last_user_idx]["content"].lower()
        history = " ".join(m.get("content") or "" for m in messages if m["role"] == "assistant").lower()
        tool_msgs = [m for m in messages[last_user_idx + 1:] if m["role"] == "tool"]

        if tool_msgs:
            return self._after_tools(tool_msgs, user_text, names, today, pins)

        pin = (re.search(r"\b\d{6}\b", user_text) or [None])[0] or (pins[0] if pins else None)
        cuisine = next((c.title() for c in CUISINES if c in user_text), None)
        plan_ref = re.findall(r"plan #(\d+)", history)
        plan_id = int(plan_ref[-1]) if plan_ref else None

        # ---- cook assistant intents
        if "get_my_cook_profile" in names:
            if any(w in user_text for w in ("rate", "price", "pricing", "charge")):
                return _call("market_rates", pincode=pin, cuisine=cuisine)
            if any(w in user_text for w in ("job", "booking", "schedule", "request", "upcoming")):
                return _call("get_my_jobs")
            if any(w in user_text for w in ("bio", "profile", "dish", "signature", "describe")):
                return _call("get_my_cook_profile")
            return LLMResponse(text="I can **write your bio**, **check your pricing** against nearby cooks, "
                                    "**suggest signature dishes**, or **summarise your upcoming jobs**. What would help?")

        # ---- customer intents
        if "plan_grocery_list" in names and any(w in user_text for w in ("grocery", "shopping", "ingredients", "buy")):
            people = int((re.search(r"(\d+)\s*(people|persons|members|of us|adults)", user_text) or [0, 2])[1])
            return _call("plan_grocery_list", plan_id=plan_id or 1, people=people)
        if "plan_nutrition" in names and plan_id and any(w in user_text for w in ("nutrition", "calorie", "protein", "macro", "kcal")):
            return _call("plan_nutrition", plan_id=plan_id)
        shown = re.findall(r"cooks shown: ([^\]]*)", history)
        if "draft_booking" in names and "book" in user_text and shown and not cuisine and not re.search(r"\b\d{6}\b", user_text):
            # follow-up like "book the top one" → use the cooks we just showed
            ids = re.findall(r"\(id (\d+)\)", shown[-1])
            if ids:
                return _call("draft_booking", cook_id=int(ids[0]), service_date=_date(user_text, today).isoformat(),
                             start_time=_time(user_text), meal_type=_meal_type(user_text),
                             guests=int(m.group(1)) if (m := re.search(r"(\d+)\s*(people|guests|persons)", user_text)) else 2)
        if "search_cooks" in names and any(w in user_text for w in ("cook", "book", "chef", "maid", "hire", "find")):
            return _call("search_cooks", pincode=pin, cuisine=cuisine, veg_only=bool(_diet(user_text) == "veg"),
                         max_rate=int(m.group(1)) if (m := re.search(r"(?:under|below|max|<)\s*₹?\s*(\d{3,4})", user_text)) else None)
        if "list_meal_plans" in names and any(w in user_text for w in (
                "plan", "diet", "chart", "week", "meal", "menu", "protein", "weight", "kid", "tiffin", "eat", "best")):
            return _call("list_meal_plans", goal=_goal(user_text), diet=_diet(user_text))
        if "plan_nutrition" in names and any(w in user_text for w in ("nutrition", "calorie", "protein", "macro")):
            return _call("plan_nutrition", plan_id=plan_id or 1)
        return LLMResponse(text="Hi! Tell me your **household size**, **diet** (veg / egg / non-veg / Jain) and any "
                                "**goal** (weight loss, high protein, kids' tiffin…). I'll suggest a weekly plan, a grocery "
                                "list and a cook who can make it.\n\n_Running in offline demo mode: connect Azure OpenAI, "
                                "Claude or Ollama in `backend/.env` for full conversations._")

    # ------------------------------------------------------------------ second step
    def _after_tools(self, tool_msgs, user_text, names, today, pins):
        last = tool_msgs[-1]
        data = json.loads(last["content"])
        name = last["name"]
        if "error" in data:
            return LLMResponse(text=f"Hmm, that didn't work: {data['error']}")

        if name == "search_cooks":
            cooks = data.get("cooks", [])
            if not cooks:
                return LLMResponse(text="I couldn't find cooks for that yet. Try another cuisine or pincode, "
                                        "or remove the price limit.")
            top = cooks[0]
            if "draft_booking" in names and "book" in user_text and not any(m["name"] == "draft_booking" for m in tool_msgs):
                return _call("draft_booking", cook_id=top["user_id"], service_date=_date(user_text, today).isoformat(),
                             start_time=_time(user_text), meal_type=_meal_type(user_text),
                             guests=int(m.group(1)) if (m := re.search(r"(\d+)\s*(people|guests|persons)", user_text)) else 2)
            lines = [f"- **{c['name']}**: {', '.join(c['cuisines'][:2])} · ₹{c['hourly_rate']}/hr · "
                     f"{'★ ' + str(c['rating_avg']) if c['rating_count'] else 'new'}{' · ✔ verified' if c['verified'] else ''}"
                     for c in cooks[:3]]
            return LLMResponse(text=f"I found **{len(cooks)} cook{'s' if len(cooks) > 1 else ''}** for you:\n"
                                    + "\n".join(lines) + f"\n\nWant me to book **{top['name']}**? Tell me the day and time.")
        if name == "draft_booking":
            return LLMResponse(text=f"Here's your booking draft (≈ **₹{data['total_inr']}**). Review it and tap "
                                    "**Confirm booking** to send the request to the cook.")
        if name == "list_meal_plans":
            plans = data.get("plans", [])
            if not plans:
                return LLMResponse(text="No plans match that yet. Try 'balanced' or 'veg'.")
            p = plans[0]
            return LLMResponse(text=f"Here {'are' if len(plans) > 1 else 'is'} **{len(plans)} diet chart{'s' if len(plans) > 1 else ''}** that fit{'' if len(plans) > 1 else 's'}. I'd start with **{p['title']}** "
                                    f"(plan #{p['id']}): about **{p['avg_kcal']} kcal** and **{p['avg_protein']} g protein** "
                                    "per person per day.\n\nWant the **nutrition breakdown**, a **grocery list**, or a **cook** for it?")
        if name == "plan_nutrition":
            a = data["daily_average"]
            s = data["macro_split_pct"]
            return LLMResponse(text=f"Daily average: **{a['kcal']} kcal**, **{a['protein']} g protein**, {a['carbs']} g carbs, "
                                    f"{a['fat']} g fat, {a['fibre']} g fibre. Energy split: protein {s['protein']}% · carbs "
                                    f"{s['carbs']}% · fat {s['fat']}%. Charts are above.")
        if name == "plan_grocery_list":
            n = sum(c["items"] for c in data["categories"])
            return LLMResponse(text=f"Your weekly grocery list for **{data['people']} people** has **{n} items** across "
                                    f"{len(data['categories'])} aisles. Tick items off as you shop.")
        if name == "market_rates":
            if not data.get("cooks_compared"):
                return LLMResponse(text="There aren't enough cooks nearby to compare yet. ₹250–350/hr is typical in Bengaluru.")
            return LLMResponse(text=f"Compared with **{data['cooks_compared']} cooks**: average **₹{data['avg_rate']}/hr** "
                                    f"(range ₹{data['min_rate']}–₹{data['max_rate']}). Top-rated cooks charge about "
                                    f"₹{data['top_rated_rate']}/hr. Price near the average until you have 5+ reviews.")
        if name == "get_my_jobs":
            jobs = data.get("jobs", [])
            if not jobs:
                return LLMResponse(text="No jobs yet. A complete profile with 4–5 signature dishes gets more requests.")
            lines = [f"- **{j['date']} {j['time']}**: {j['customer']}, {j['meal_type'].replace('_', ' ')} for "
                     f"{j['guests']} ({j['status'].replace('_', ' ')}){' · ' + j['notes'] if j['notes'] else ''}"
                     for j in jobs[:5]]
            return LLMResponse(text="Your jobs:\n" + "\n".join(lines))
        if name == "get_my_cook_profile" and "suggest_profile_update" in names:
            cuisines = data.get("cuisines") or ["South Indian"]
            yrs = data.get("experience_years", 0)
            bio = (f"Home cook with {yrs}+ years of experience in {' & '.join(cuisines[:2])} food. I cook fresh, "
                   f"hygienic, less-oil meals the way your family likes, from daily tiffin to weekend feasts. "
                   f"Punctual, clean kitchen guaranteed.")
            return _call("suggest_profile_update", bio=bio, reason="A warmer bio with experience and hygiene up front.",
                         new_dishes=[{"name": "Bisi Bele Bath", "cuisine": "Karnataka", "is_veg": True},
                                     {"name": "Paneer Butter Masala", "cuisine": "North Indian", "is_veg": True}]
                         if "dish" in user_text else None)
        if name == "suggest_profile_update":
            return LLMResponse(text="I've drafted an update. Review it and tap **Apply** to save it to your profile.")
        return LLMResponse(text="Done. Anything else?")
