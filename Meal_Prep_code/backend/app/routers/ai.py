from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..ai.agents import AGENTS, agents_for_role
from ..ai.engine import follow_ups, run_agent
from ..ai.providers import PROVIDER_LABELS, ProviderError, configured_providers, get_provider
from ..auth import current_user
from ..config import get_settings
from ..db import get_db
from ..models import AIConversation, User

router = APIRouter(prefix="/ai", tags=["ai"])


class ChatIn(BaseModel):
    agent: str
    message: str = Field(min_length=1, max_length=4000)
    conversation_id: int | None = None
    provider: str | None = None  # override the server default (must be configured)


def _conv_out(c: AIConversation, full: bool = False) -> dict:
    last = next((m for m in reversed(c.messages) if m["role"] == "assistant"), None)
    out = {"id": c.id, "agent": c.agent, "title": c.title, "provider": c.provider,
           "updated_at": c.updated_at, "preview": (last or {}).get("content", "")[:120]}
    if full:
        out["messages"] = c.messages
    return out


@router.get("/agents")
def list_agents(user: User = Depends(current_user)):
    default = get_settings().ai_provider
    avail = configured_providers()
    return {
        "agents": [{"key": a.key, "title": a.title, "tagline": a.tagline, "icon": a.icon, "color": a.color,
                    "starters": list(a.starters)} for a in agents_for_role(user.role.value)],
        "providers": [{"key": k, "label": PROVIDER_LABELS[k]} for k in avail],
        "default_provider": default if default in avail else "mock",
    }


@router.post("/chat")
def chat(body: ChatIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    agent = AGENTS.get(body.agent)
    if not agent or (user.role.value not in agent.roles and user.role.value != "admin"):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown agent")

    if body.conversation_id:
        conv = db.get(AIConversation, body.conversation_id)
        if not conv or conv.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Conversation not found")
    else:
        conv = AIConversation(user_id=user.id, agent=agent.key, title=body.message[:60], messages=[])

    try:
        provider = get_provider(body.provider)
        result = run_agent(provider, agent, db, user, conv.messages, body.message)
    except ProviderError as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(exc)) from exc

    suggestions = follow_ups(agent, result.blocks)
    conv.messages = [*conv.messages,
                     {"role": "user", "content": body.message},
                     {"role": "assistant", "content": result.reply, "blocks": result.blocks,
                      "suggestions": suggestions, "tools": result.tool_trace}]
    conv.provider = provider.name
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return {"conversation_id": conv.id, "reply": result.reply, "blocks": result.blocks,
            "suggestions": suggestions, "provider": provider.name, "tools": result.tool_trace}


@router.get("/conversations")
def conversations(user: User = Depends(current_user), db: Session = Depends(get_db)):
    q = select(AIConversation).where(AIConversation.user_id == user.id).order_by(AIConversation.updated_at.desc())
    return [_conv_out(c) for c in db.scalars(q.limit(50)).all()]


@router.get("/conversations/{conv_id}")
def conversation(conv_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    c = db.get(AIConversation, conv_id)
    if not c or c.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Conversation not found")
    return _conv_out(c, full=True)


@router.delete("/conversations/{conv_id}", status_code=204)
def delete_conversation(conv_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    c = db.get(AIConversation, conv_id)
    if not c or c.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Conversation not found")
    db.delete(c)
    db.commit()
