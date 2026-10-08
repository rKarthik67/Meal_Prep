"""The agent loop: model → tools → model … until it answers in text."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models import Address, User
from .agents import COMMON_RULES, Agent
from .providers import Provider
from .tools import TOOLS, ToolContext, run_tool

log = logging.getLogger("ai")

MAX_HISTORY = 20  # turns of past conversation sent to the model


@dataclass
class AgentResult:
    reply: str
    blocks: list[dict]
    tool_trace: list[dict]


def system_prompt(agent: Agent, db: Session, user: User) -> str:
    pins = sorted({a.pincode for a in db.scalars(select(Address).where(Address.user_id == user.id))})
    rules = COMMON_RULES.format(today=date.today().isoformat(), name=user.name or "there",
                                role=user.role.value, pincodes=", ".join(pins) or "none saved")
    return f"{agent.prompt}\n\n{rules}"


def _block_note(b: dict) -> str:
    """Compact memory of the cards shown, so follow-ups like 'that plan' resolve correctly."""
    t = b["type"]
    if t == "cooks":
        return "cooks shown: " + ", ".join(f"{c['name']} (id {c['user_id']})" for c in b["cooks"][:5])
    if t == "meal_plans":
        return "plans shown: " + ", ".join(f"plan #{p['id']} {p['title']}" for p in b["plans"][:8])
    if t == "meal_plan":
        return f"plan #{b['plan']['id']} {b['plan']['title']}"
    if t in ("nutrition", "grocery_list"):
        return f"{t} for plan #{b['plan_id']}"
    if t == "booking_draft":
        return f"booking draft for cook id {b['payload']['cook_id']} on {b['payload']['service_date']}"
    return t


def history_for_model(messages: list[dict]) -> list[dict]:
    out = []
    for m in messages[-MAX_HISTORY:]:
        content = m["content"]
        if m["role"] == "assistant" and m.get("blocks"):
            content += "\n[" + "; ".join(_block_note(b) for b in m["blocks"]) + "]"
        out.append({"role": m["role"], "content": content})
    return out


def run_agent(provider: Provider, agent: Agent, db: Session, user: User,
              past: list[dict], user_message: str) -> AgentResult:
    ctx = ToolContext(db=db, user=user)
    tools = [TOOLS[n].schema() for n in agent.tools]
    system = system_prompt(agent, db, user)
    msgs = history_for_model(past) + [{"role": "user", "content": user_message}]
    trace: list[dict] = []

    for _ in range(get_settings().ai_max_steps):
        resp = provider.chat(system, msgs, tools)
        if not resp.tool_calls:
            return AgentResult(reply=resp.text.strip() or "Done.", blocks=ctx.blocks, tool_trace=trace)
        msgs.append({"role": "assistant", "content": resp.text, "tool_calls": resp.tool_calls})
        for tc in resp.tool_calls:
            if tc.name not in agent.tools:
                result = {"error": f"Tool {tc.name} is not available to this agent."}
            else:
                result = run_tool(ctx, tc.name, tc.arguments)
            log.info("tool %s(%s) -> %s", tc.name, tc.arguments, str(result)[:200])
            trace.append({"tool": tc.name, "args": tc.arguments, "ok": "error" not in result})
            msgs.append({"role": "tool", "tool_call_id": tc.id, "name": tc.name,
                         "content": json.dumps(result, default=str)})

    # Ran out of steps: ask for a final answer without tools.
    final = provider.chat(system + "\n\nAnswer now without calling tools.", msgs, [])
    return AgentResult(reply=final.text.strip() or "Here's what I found.", blocks=ctx.blocks, tool_trace=trace)


def follow_ups(agent: Agent, blocks: list[dict]) -> list[str]:
    types = {b["type"] for b in blocks}
    if "booking_draft" in types:
        return ["Change the time to 9am", "Make it 4 people", "Find a cheaper cook"]
    if "cooks" in types:
        return ["Book the top one for tomorrow 8am", "Only verified cooks", "Show cheaper options"]
    if "grocery_list" in types:
        return ["Find a cook for this plan", "Show nutrition", "Scale to 4 people"]
    if "nutrition" in types:
        return ["Make it higher protein", "Grocery list for 2", "Find a cook for this plan"]
    if "meal_plans" in types or "meal_plan" in types:
        return ["Show nutrition for the first plan", "Grocery list for 3 people", "Find a cook for it"]
    if "profile_suggestion" in types:
        return ["Make the bio shorter", "Suggest my hourly rate", "Summarise my upcoming jobs"]
    return list(agent.starters[:3])
