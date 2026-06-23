"""
agent_core.py — shared foundation for ButterFold's deep (reason+act) agents.

Two primitives that turn a static prompt into a ReAct agent:

  Journal      — persistent cross-iteration MEMORY (generated/context.json).
                 Threaded through every agent so each step builds on prior
                 knowledge instead of starting cold. Tagged with a spec hash so
                 stale entries (from before a spec change) are visible/ignored.

  (Action harness + react_loop live alongside this; see register_default_actions
   and react_loop below once added.)

Design rule: the deterministic parts work with NO API key. Only the LLM-driven
ReAct loop needs OpenAI; everything here (memory) is pure stdlib and testable on
the host.
"""
from __future__ import annotations
import json, time, hashlib, pathlib, subprocess, sys
from typing import Optional

ROOT        = pathlib.Path(__file__).parent.parent
JOURNAL     = ROOT / "generated" / "context.json"
SPEC_FILES  = [ROOT / "modular_description.md", ROOT / "butterfold_module_io.md"]
RTL_DIR     = ROOT / "generated" / "rtl"


def spec_hash() -> str:
    """Short hash of the current spec files — used to detect staleness."""
    h = hashlib.sha256()
    for p in SPEC_FILES:
        if p.exists():
            h.update(p.read_bytes())
    return h.hexdigest()[:12]


class Journal:
    """Append-only run memory, persisted to generated/context.json.

    Each entry: {ts, agent, kind, summary, data, stale}. 'kind' is free-form
    ('plan', 'finding', 'action', 'observation', 'decision', 'error'). Entries
    written under a previous spec hash are flagged stale=True on load so agents
    can down-weight them instead of being misled.
    """

    def __init__(self, path: pathlib.Path = JOURNAL):
        self.path = path
        self.spec = spec_hash()
        self.entries: list[dict] = []
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            return
        try:
            doc = json.loads(self.path.read_text())
        except (json.JSONDecodeError, OSError):
            return
        prior = doc.get("spec_hash")
        for e in doc.get("entries", []):
            # Mark entries from a different spec version as stale.
            e["stale"] = e.get("stale", False) or (prior != self.spec)
            self.entries.append(e)

    def append(self, agent: str, kind: str, summary: str,
               data: Optional[dict] = None) -> dict:
        entry = {
            "ts": round(time.time(), 3),
            "agent": agent,
            "kind": kind,
            "summary": summary[:500],
            "data": data or {},
            "stale": False,
        }
        self.entries.append(entry)
        self.save()
        return entry

    def recent(self, n: int = 12, agent: Optional[str] = None,
               include_stale: bool = False) -> list[dict]:
        items = [e for e in self.entries
                 if (include_stale or not e["stale"])
                 and (agent is None or e["agent"] == agent)]
        return items[-n:]

    def context_block(self, n: int = 12) -> str:
        """Compact, prompt-ready summary of recent fresh memory."""
        rows = self.recent(n)
        if not rows:
            return "(no prior context)"
        return "\n".join(
            f"- [{e['agent']}/{e['kind']}] {e['summary']}" for e in rows
        )

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        doc = {
            "spec_hash": self.spec,
            "updated": round(time.time(), 3),
            "entries": self.entries,
        }
        self.path.write_text(json.dumps(doc, indent=2), encoding="utf-8")

    def reset(self) -> None:
        """Clear memory (e.g. start a fresh design run)."""
        self.entries = []
        self.save()


def _obs(ok: bool, summary: str, **data) -> dict:
    """Structured observation returned by every action."""
    return {"ok": bool(ok), "summary": summary, "data": data}


class ActionHarness:
    """The ACT surface: tools an agent can CHOOSE to invoke, each returning a
    structured observation. EDA tools (iverilog/yosys) need the Docker container;
    when absent they return ok=False with a clear reason, so the harness is still
    importable/testable on the host. File + kernel-regen actions run anywhere.

    Every call is logged to the Journal (action + observation) so the ReAct loop
    and future runs see what was tried and what happened.
    """

    def __init__(self, journal: Optional["Journal"] = None, agent: str = "agent"):
        self.journal = journal
        self.agent = agent

    def _log(self, action: str, args: dict, obs: dict) -> dict:
        if self.journal:
            self.journal.append(self.agent, "action", f"{action}: {obs['summary']}",
                                {"action": action, "args": args, "ok": obs["ok"]})
        return obs

    def _run(self, cmd: list, timeout: int = 300) -> tuple[int, str]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            return r.returncode, (r.stdout + r.stderr)
        except FileNotFoundError:
            return 127, f"tool not found: {cmd[0]} (run inside the Docker container)"
        except subprocess.TimeoutExpired:
            return 124, f"timeout after {timeout}s"

    # ── file actions (host-runnable) ────────────────────────────────────────
    def read_file(self, path: str, max_chars: int = 8000) -> dict:
        p = (ROOT / path) if not pathlib.Path(path).is_absolute() else pathlib.Path(path)
        if not p.exists():
            return self._log("read_file", {"path": path}, _obs(False, f"missing: {path}"))
        txt = p.read_text(encoding="utf-8", errors="replace")[:max_chars]
        return self._log("read_file", {"path": path},
                         _obs(True, f"read {p.name} ({len(txt)} chars)", content=txt))

    def edit_file(self, path: str, old: str, new: str) -> dict:
        p = (ROOT / path) if not pathlib.Path(path).is_absolute() else pathlib.Path(path)
        if not p.exists():
            return self._log("edit_file", {"path": path}, _obs(False, f"missing: {path}"))
        txt = p.read_text(encoding="utf-8")
        if old not in txt:
            return self._log("edit_file", {"path": path}, _obs(False, "old string not found"))
        p.write_text(txt.replace(old, new, 1), encoding="utf-8")
        return self._log("edit_file", {"path": path}, _obs(True, f"edited {p.name}"))

    def list_rtl(self) -> dict:
        files = sorted(p.name for p in RTL_DIR.glob("*.v") if not p.name.startswith("tb_"))
        return self._log("list_rtl", {}, _obs(True, f"{len(files)} rtl file(s)", files=files))

    # ── kernel-as-tool: agent commands the generator, never types constants ──
    def regen_kernel(self) -> dict:
        gen = ROOT / "gen_reference.py"
        rc, out = self._run([sys.executable, str(gen)], timeout=300)
        evm = None
        for line in out.splitlines():
            if "EVM =" in line:
                try: evm = float(line.split("EVM =")[1].split("%")[0])
                except (ValueError, IndexError): pass
        ok = rc == 0 and evm is not None
        return self._log("regen_kernel", {}, _obs(ok, f"kernel regenerated, EVM={evm}%", evm=evm))

    # ── EDA actions (need the Docker container) ─────────────────────────────
    def _rtl_sources(self) -> list:
        return [str(p) for p in sorted(RTL_DIR.glob("*.v")) if not p.name.startswith("tb_")]

    def compile(self) -> dict:
        rc, out = self._run(["iverilog", "-g2012", "-Wall", "-t", "null", *self._rtl_sources()])
        summary = ("syntax OK" if rc == 0 else
                   "iverilog unavailable (need container)" if rc == 127 else "compile errors")
        return self._log("compile", {}, _obs(rc == 0, summary, rc=rc, log=out[-2000:]))

    def yosys_check(self) -> dict:
        srcs = " ".join(self._rtl_sources())
        script = (f"read_verilog -sv {srcs}; hierarchy -top butterfold_top -check; "
                  f"proc; opt -fast; check")
        rc, out = self._run(["yosys", "-q", "-p", script])
        ok = rc == 0 and "ERROR" not in out.upper()
        return self._log("yosys_check", {}, _obs(ok, "elaboration OK" if ok else "yosys error",
                                                  rc=rc, log=out[-2000:]))

    def golden_evm(self) -> dict:
        """Authoritative bit-exact gate — delegates to verify.agent's stage 6."""
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("verify_agent", ROOT / "agents" / "verify.agent.py")
            va = importlib.util.module_from_spec(spec); spec.loader.exec_module(va)
            res = va.stage_golden_model_check(RTL_DIR / "butterfold_top.v")
            ok = res.get("golden_ok") is True
            return self._log("golden_evm", {}, _obs(ok, f"golden EVM={res.get('evm_percent')}%", **res))
        except Exception as exc:
            return self._log("golden_evm", {}, _obs(False, f"golden check unavailable: {exc}"))


# ── ReAct loop controller ────────────────────────────────────────────────────
# Maps tool name -> (HarnessMethod, OpenAI parameter schema).
_TOOLS = {
    "read_file":    ({"path": "string"}, ["path"], "Read a repo file (relative path)."),
    "edit_file":    ({"path": "string", "old": "string", "new": "string"},
                     ["path", "old", "new"], "Replace the first exact occurrence of 'old' with 'new'."),
    "list_rtl":     ({}, [], "List the synthesizable RTL files in generated/rtl."),
    "compile":      ({}, [], "iverilog syntax check over all RTL (needs container)."),
    "yosys_check":  ({}, [], "Yosys structural elaboration check (needs container)."),
    "golden_evm":   ({}, [], "Run the authoritative bit-exact golden EVM gate (needs container)."),
    "regen_kernel": ({}, [], "Re-run the deterministic generator and observe the kernel EVM."),
    "done":         ({"status": "string", "summary": "string"}, ["status", "summary"],
                     "Finish: status='success' or 'blocked', with a one-line summary."),
}


def _tool_schemas() -> list:
    schemas = []
    for name, (props, required, desc) in _TOOLS.items():
        schemas.append({"type": "function", "function": {
            "name": name, "description": desc,
            "parameters": {"type": "object",
                           "properties": {k: {"type": v} for k, v in props.items()},
                           "required": required},
        }})
    return schemas


REACT_SYSTEM = """\
You are a deep RTL engineering agent that REASONS then ACTS. You achieve the goal
by calling tools one at a time, observing each result, and deciding the next step
— not by emitting a wall of code.

Rules:
- The bit-exact DSP datapath lives in the LOCKED butterfold_kernel; never author or
  edit its twiddle constants. To change kernel behaviour, call regen_kernel and
  observe the EVM — command the generator, do not hand-write constants.
- Edit only the wrapper/control RTL.
- Work in SMALL STEPS: make ONE minimal edit_file, then IMMEDIATELY run compile, then
  golden_evm, before making any further edit. Never make two edits in a row without
  re-checking in between.
- If compile reports errors, your MOST RECENT edit was wrong: read_file and fix or
  revert exactly that change before doing anything else. Do not pile on new edits.
- Diagnose the ACTUAL failure from compile/golden_evm output. Any error text handed to
  you in the goal may be stale — trust the live tool observations over it.
- The golden EVM gate (EVM < 2%) is the authoritative success test.
- Use prior journal context; never repeat an action that already failed the same way.
- Every turn you MUST call exactly one tool, or call 'done'. Never reply with prose
  only. Call done(status='success') once golden_evm passes, or done(status='blocked')
  if truly stuck, always with a short summary."""


def react_loop(goal: str, harness: "ActionHarness", journal: "Journal",
               agent: str = "agent", model: str = "gpt-4o", max_steps: int = 12) -> dict:
    """think -> act -> observe loop using OpenAI tool-calling.

    Returns {"ok", "status", "steps", "reason"}. If no API key is set, returns
    {"ok": False, "fallback": True} so the caller runs today's scripted path —
    keeping the whole system usable without an LLM (open-source constraint).
    """
    import os
    if not os.environ.get("OPENAI_API_KEY"):
        journal.append(agent, "decision", "no API key — falling back to scripted pipeline")
        return {"ok": False, "fallback": True, "reason": "no_api_key"}

    import openai
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    dispatch = {
        "read_file": harness.read_file, "edit_file": harness.edit_file,
        "list_rtl": harness.list_rtl, "compile": harness.compile,
        "yosys_check": harness.yosys_check, "golden_evm": harness.golden_evm,
        "regen_kernel": harness.regen_kernel,
    }
    messages = [
        {"role": "system", "content": REACT_SYSTEM},
        {"role": "user", "content": f"GOAL:\n{goal}\n\nPRIOR CONTEXT:\n{journal.context_block()}"},
    ]

    stalls = 0
    for step in range(1, max_steps + 1):
        resp = client.chat.completions.create(
            model=model, messages=messages,
            tools=_tool_schemas(), tool_choice="auto", max_tokens=1024)
        msg = resp.choices[0].message

        if not msg.tool_calls:
            # Anti-stall: nudge the model back into act-mode instead of giving up.
            stalls += 1
            journal.append(agent, "decision", f"no tool call (nudge {stalls})")
            if stalls > 2:
                return {"ok": False, "status": "stalled", "steps": step, "reason": "no_tool_call"}
            messages.append({"role": "assistant", "content": msg.content or ""})
            messages.append({"role": "user", "content":
                "You replied with prose. You MUST call exactly one tool now "
                "(compile, golden_evm, read_file, edit_file, regen_kernel), or call "
                "done() if golden_evm already passes. Re-read the latest tool output "
                "and take the single next action."})
            continue

        messages.append({"role": "assistant", "content": msg.content or "",
                         "tool_calls": [{"id": tc.id, "type": "function",
                                         "function": {"name": tc.function.name,
                                                      "arguments": tc.function.arguments}}
                                        for tc in msg.tool_calls]})

        for tc in msg.tool_calls:
            name = tc.function.name
            try:
                args = json.loads(tc.function.arguments or "{}")
            except json.JSONDecodeError:
                args = {}

            if name == "done":
                status = args.get("status", "blocked")
                journal.append(agent, "decision", f"done [{status}]: {args.get('summary', '')}")
                return {"ok": status == "success", "status": status,
                        "steps": step, "summary": args.get("summary", "")}

            fn = dispatch.get(name)
            obs = fn(**args) if fn else _obs(False, f"unknown tool: {name}")
            messages.append({"role": "tool", "tool_call_id": tc.id,
                             "content": json.dumps(obs)[:3000]})

    journal.append(agent, "decision", f"hit max_steps ({max_steps}) without finishing")
    return {"ok": False, "status": "max_steps", "steps": max_steps, "reason": "max_steps"}


# ── self-test (host, no API key) ─────────────────────────────────────────────
if __name__ == "__main__":
    import tempfile, os
    tmp = pathlib.Path(tempfile.mkdtemp()) / "context.json"
    j = Journal(tmp)
    j.reset()
    j.append("planner", "plan", "decomposed into 6 modules", {"modules": 6})
    j.append("code", "action", "ran golden_evm", {"evm": 1.5915})
    j.append("debug", "decision", "widen samp to 8 bits after width error")
    j2 = Journal(tmp)  # reload from disk
    assert len(j2.entries) == 3, j2.entries
    assert j2.recent(2)[0]["agent"] == "code"
    print("[agent_core] Journal self-test OK")
    print("[agent_core] context block:\n" + j2.context_block())
    os.remove(tmp)

    # ── ActionHarness: host-runnable actions + graceful EDA-tool absence ─────
    h = ActionHarness(agent="selftest")
    r_list = h.list_rtl()
    print(f"[agent_core] list_rtl -> ok={r_list['ok']} {r_list['summary']}")
    r_read = h.read_file("modular_description.md", max_chars=200)
    print(f"[agent_core] read_file -> ok={r_read['ok']} {r_read['summary']}")
    r_comp = h.compile()  # iverilog absent on host -> ok=False, clear reason
    print(f"[agent_core] compile -> ok={r_comp['ok']} {r_comp['summary']}")
    assert r_read["ok"] and not r_comp["ok"]   # file action works; EDA degrades gracefully
    print("[agent_core] ActionHarness self-test OK (EDA tools degrade gracefully off-container)")

    # ── ReAct loop: no-key fallback path (host) ─────────────────────────────
    import os as _os
    _saved = _os.environ.pop("OPENAI_API_KEY", None)
    jr = Journal(tmp); jr.reset()
    res = react_loop("smoke test", ActionHarness(jr, "selftest"), jr, agent="selftest")
    assert res.get("fallback") is True and res["reason"] == "no_api_key", res
    print(f"[agent_core] react_loop no-key fallback OK -> {res}")
    if _saved is not None:
        _os.environ["OPENAI_API_KEY"] = _saved
    _os.remove(tmp)
