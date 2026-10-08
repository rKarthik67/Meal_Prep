"""LLM providers behind one tiny interface so agents don't care who answers.

Neutral message format used by the agent loop:
    {"role": "user", "content": str}
    {"role": "assistant", "content": str, "tool_calls": [ToolCall, ...]}
    {"role": "tool", "tool_call_id": str, "name": str, "content": str(JSON)}
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field

from ..config import get_settings


class ProviderError(RuntimeError):
    pass


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict


@dataclass
class LLMResponse:
    text: str = ""
    tool_calls: list[ToolCall] = field(default_factory=list)


class Provider:
    name = "base"
    label = "Base"

    def chat(self, system: str, messages: list[dict], tools: list[dict]) -> LLMResponse:  # pragma: no cover
        raise NotImplementedError


# ---------------------------------------------------------------- OpenAI-compatible (Azure, Ollama)
class OpenAICompatProvider(Provider):
    def __init__(self, client, model: str, name: str, label: str):
        self.client, self.model, self.name, self.label = client, model, name, label

    def chat(self, system, messages, tools):
        msgs: list[dict] = [{"role": "system", "content": system}]
        for m in messages:
            if m["role"] == "tool":
                msgs.append({"role": "tool", "tool_call_id": m["tool_call_id"], "content": m["content"]})
            elif m["role"] == "assistant" and m.get("tool_calls"):
                msgs.append({
                    "role": "assistant",
                    "content": m.get("content") or None,
                    "tool_calls": [
                        {"id": tc.id, "type": "function",
                         "function": {"name": tc.name, "arguments": json.dumps(tc.arguments)}}
                        for tc in m["tool_calls"]
                    ],
                })
            else:
                msgs.append({"role": m["role"], "content": m["content"]})
        kwargs = {"model": self.model, "messages": msgs}
        if tools:
            kwargs["tools"] = [
                {"type": "function", "function": {"name": t["name"], "description": t["description"],
                                                  "parameters": t["parameters"]}}
                for t in tools
            ]
        try:
            resp = self.client.chat.completions.create(**kwargs)
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"{self.label} request failed: {exc}") from exc
        msg = resp.choices[0].message
        calls = []
        for tc in msg.tool_calls or []:
            try:
                args = json.loads(tc.function.arguments or "{}")
            except json.JSONDecodeError:
                args = {}
            calls.append(ToolCall(id=tc.id, name=tc.function.name, arguments=args))
        return LLMResponse(text=msg.content or "", tool_calls=calls)


# ---------------------------------------------------------------- Anthropic
class AnthropicProvider(Provider):
    name, label = "anthropic", "Claude"

    def __init__(self, client, model: str):
        self.client, self.model = client, model

    def chat(self, system, messages, tools):
        out: list[dict] = []
        for m in messages:
            if m["role"] == "tool":
                block = {"type": "tool_result", "tool_use_id": m["tool_call_id"], "content": m["content"]}
                if out and out[-1]["role"] == "user" and isinstance(out[-1]["content"], list):
                    out[-1]["content"].append(block)  # group parallel tool results into one turn
                else:
                    out.append({"role": "user", "content": [block]})
            elif m["role"] == "assistant":
                content: list[dict] = []
                if m.get("content"):
                    content.append({"type": "text", "text": m["content"]})
                for tc in m.get("tool_calls") or []:
                    content.append({"type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.arguments})
                out.append({"role": "assistant", "content": content or [{"type": "text", "text": "…"}]})
            else:
                out.append({"role": "user", "content": m["content"]})
        try:
            resp = self.client.messages.create(
                model=self.model, max_tokens=2048, system=system, messages=out,
                tools=[{"name": t["name"], "description": t["description"], "input_schema": t["parameters"]}
                       for t in tools],
            )
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"Claude request failed: {exc}") from exc
        text, calls = [], []
        for b in resp.content:
            if b.type == "text":
                text.append(b.text)
            elif b.type == "tool_use":
                calls.append(ToolCall(id=b.id, name=b.name, arguments=dict(b.input or {})))
        return LLMResponse(text="\n".join(text).strip(), tool_calls=calls)


# ---------------------------------------------------------------- registry
PROVIDER_LABELS = {"azure": "Azure OpenAI", "anthropic": "Claude", "ollama": "Ollama (local)", "mock": "Demo (offline)"}


def configured_providers() -> list[str]:
    s = get_settings()
    out = []
    if s.azure_openai_endpoint and s.azure_openai_api_key and s.azure_openai_deployment:
        out.append("azure")
    if s.anthropic_api_key:
        out.append("anthropic")
    if s.ollama_base_url and s.ollama_model:
        out.append("ollama")  # reachability is checked when used
    out.append("mock")
    return out


def get_provider(name: str | None = None) -> Provider:
    s = get_settings()
    name = (name or s.ai_provider or "mock").lower()
    if name == "azure":
        if not (s.azure_openai_endpoint and s.azure_openai_api_key and s.azure_openai_deployment):
            raise ProviderError("Azure OpenAI is not configured (AZURE_OPENAI_* in backend/.env).")
        from openai import AzureOpenAI

        client = AzureOpenAI(azure_endpoint=s.azure_openai_endpoint, api_key=s.azure_openai_api_key,
                             api_version=s.azure_openai_api_version, timeout=90)
        return OpenAICompatProvider(client, s.azure_openai_deployment, "azure", PROVIDER_LABELS["azure"])
    if name == "anthropic":
        if not s.anthropic_api_key:
            raise ProviderError("Claude is not configured (ANTHROPIC_API_KEY in backend/.env).")
        import anthropic

        return AnthropicProvider(anthropic.Anthropic(api_key=s.anthropic_api_key, timeout=90), s.anthropic_model)
    if name == "ollama":
        from openai import OpenAI

        client = OpenAI(base_url=s.ollama_base_url.rstrip("/") + "/v1", api_key="ollama", timeout=180)
        return OpenAICompatProvider(client, s.ollama_model, "ollama", PROVIDER_LABELS["ollama"])
    if name == "mock":
        from .mock import MockProvider

        return MockProvider()
    raise ProviderError(f"Unknown AI provider '{name}'")
