"""
llm_provider.py — model-agnostic LLM factory for the agentic workflow.

Answers "which foundation model does this depend on?" with a config, not a
hardcode: point BUTTERFOLD_LLM_PROVIDER / BUTTERFOLD_LLM_BASE_URL /
BUTTERFOLD_LLM_MODEL at ANY OpenAI-compatible chat-completions endpoint —
OpenAI itself, or a locally-served OPEN-WEIGHT model (Ollama, vLLM,
llama.cpp's server, LM Studio, text-generation-webui, TGI) — and every agent
in this package runs unchanged. There is no code path that only works with a
proprietary API: "openai" and "openweight" both go through the same
ChatOpenAI client class, just a different base_url/model.

If no provider is configured (no key, no base_url), get_llm() returns None
and every caller in this package falls back to its deterministic, no-LLM
path (module_spec.skeleton, golden_agent's standalone models, ...) — the
workflow still runs end-to-end without any model at all.

Every LLM call made through get_llm()'s returned model, when invoked with
callbacks_config(), is appended to generated/logs/llm_calls.jsonl with the
exact prompt, response, model name, provider, and sampling settings — the
reproducibility trail (prompts / settings / logs) reviewers asked for.

Provider selection (env vars):
  BUTTERFOLD_LLM_PROVIDER   openai | openweight | none | auto (default: auto)
  BUTTERFOLD_LLM_BASE_URL   OpenAI-compatible base URL for "openweight"
                             (e.g. http://localhost:11434/v1 for Ollama,
                              http://localhost:8000/v1 for vLLM)
  BUTTERFOLD_LLM_MODEL      model name/tag (e.g. "gpt-4o-mini", "qwen2.5-coder:32b",
                             "llama3.1", "deepseek-coder-v2")
  BUTTERFOLD_LLM_API_KEY    api key for the openweight endpoint (most local
                             servers ignore it; default "not-needed")
  OPENAI_API_KEY            api key for the "openai" provider
  BUTTERFOLD_LLM_TEMPERATURE  sampling temperature (default 0)

  auto: "openweight" if BUTTERFOLD_LLM_BASE_URL is set, else "openai" if
  OPENAI_API_KEY looks real, else "none".
"""
from __future__ import annotations
import os, json, pathlib, time

ROOT = pathlib.Path(__file__).parent.parent
LOG_PATH = ROOT / "generated" / "logs" / "llm_calls.jsonl"

try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    pass


def _log(record: dict) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    record = {"ts": round(time.time(), 3), **record}
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, default=str) + "\n")


def active_config() -> dict:
    """What provider/model get_llm() would build, without building it. Recorded
    verbatim into generated/logs/run_manifest.json by orchestrator.py so every
    run's report states exactly which model (if any) produced it."""
    provider = os.environ.get("BUTTERFOLD_LLM_PROVIDER", "auto").lower()
    base_url = os.environ.get("BUTTERFOLD_LLM_BASE_URL")
    openai_key = os.environ.get("OPENAI_API_KEY")
    has_openai_key = bool(openai_key) and openai_key != "your_api_key_here"

    if provider == "auto":
        if base_url:
            provider = "openweight"
        elif has_openai_key:
            provider = "openai"
        else:
            provider = "none"

    if provider == "openweight" and not base_url:
        provider = "none"  # asked for openweight but gave no endpoint
    if provider == "openai" and not has_openai_key:
        provider = "none"

    default_model = {"openai": "gpt-4o-mini", "openweight": "llama3.1"}.get(provider)
    model = os.environ.get("BUTTERFOLD_LLM_MODEL") or default_model

    return {
        "provider": provider,
        "model": model,
        "base_url": base_url if provider == "openweight" else None,
        "temperature": float(os.environ.get("BUTTERFOLD_LLM_TEMPERATURE", "0")),
        "open_source_model": provider == "openweight",
    }


def get_llm():
    """Return a langchain BaseChatModel for the configured provider, or None."""
    cfg = active_config()
    if cfg["provider"] == "none":
        return None
    try:
        from langchain_openai import ChatOpenAI
    except ImportError:
        print("[llm_provider] langchain-openai not installed — deterministic fallback")
        return None

    kwargs = {"model": cfg["model"], "temperature": cfg["temperature"]}
    if cfg["provider"] == "openweight":
        kwargs["base_url"] = cfg["base_url"]
        kwargs["api_key"] = os.environ.get("BUTTERFOLD_LLM_API_KEY", "not-needed")
    else:
        kwargs["api_key"] = os.environ["OPENAI_API_KEY"]

    try:
        return ChatOpenAI(**kwargs)
    except Exception as exc:
        print(f"[llm_provider] failed to init {cfg['provider']} model {cfg['model']!r}: {exc}")
        return None


def callbacks_config() -> dict:
    """LangChain run config that logs every LLM call made during that invocation
    (including every step of a multi-turn ReAct loop) to llm_calls.jsonl."""
    return {"callbacks": [JsonlLoggingHandler(active_config())]}


def _msg_dict(m) -> dict:
    if isinstance(m, dict):
        return m
    return {"role": getattr(m, "type", "unknown"), "content": getattr(m, "content", str(m))}


try:
    from langchain_core.callbacks.base import BaseCallbackHandler

    class JsonlLoggingHandler(BaseCallbackHandler):
        """Appends every chat-model call in the run to generated/logs/llm_calls.jsonl:
        provider, model, settings, full message list, response, latency. This is
        the execution log an outside reviewer can read to audit exactly what was
        prompted and what came back, for every agent step."""

        def __init__(self, cfg: dict):
            self.cfg = cfg
            self._starts: dict = {}

        def on_chat_model_start(self, serialized, messages, *, run_id, **kwargs):
            self._starts[run_id] = {
                "t0": time.time(),
                "messages": [[_msg_dict(m) for m in batch] for batch in messages],
            }

        def on_llm_end(self, response, *, run_id, **kwargs):
            start = self._starts.pop(run_id, {"t0": time.time(), "messages": None})
            try:
                gens = [[g.text for g in batch] for batch in response.generations]
            except Exception:
                gens = str(response)
            _log({"call_id": str(run_id), **self.cfg,
                  "messages": start["messages"], "response": gens,
                  "latency_s": round(time.time() - start["t0"], 3)})

        def on_llm_error(self, error, *, run_id, **kwargs):
            start = self._starts.pop(run_id, {"t0": time.time(), "messages": None})
            _log({"call_id": str(run_id), **self.cfg,
                  "messages": start["messages"], "error": str(error),
                  "latency_s": round(time.time() - start["t0"], 3)})

except ImportError:
    class JsonlLoggingHandler:  # langchain_core not installed -> inert no-op
        def __init__(self, cfg: dict):
            self.cfg = cfg


if __name__ == "__main__":
    cfg = active_config()
    print("[llm_provider] active configuration:")
    for k, v in cfg.items():
        print(f"  {k:<18} {v}")
    llm = get_llm()
    print(f"[llm_provider] model object: {'built OK' if llm else 'None (deterministic fallback active)'}")
