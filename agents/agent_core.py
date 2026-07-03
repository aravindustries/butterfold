"""
agent_core.py — shared foundation for ButterFold's deep (reason+act) agents,
rebuilt for MODULAR AUTHORING.

The single source of truth is butterfold_module_io.md (parsed by module_spec).
Agents author each of the 6 modules + the top from its port contract; there is
no flat generator, no locked kernel, no golden-byte copy. Correctness per module
is established by: exact port conformance, iverilog compile, yosys elaboration,
and the module's own testbench when present.

Two primitives:
  Journal         — persistent cross-step memory (generated/context.json).
  ModuleHarness   — the ACT surface for authoring ONE module: read its contract,
                    read/write its RTL, compile it, elaborate it, run its tb.
  react_loop      — think -> act -> observe over the harness (OpenAI tool-calling),
                    with a no-API-key fallback so the pipeline still runs.
"""
from __future__ import annotations
import json, time, hashlib, pathlib, subprocess, os
from typing import Optional

ROOT       = pathlib.Path(__file__).parent.parent
JOURNAL    = ROOT / "generated" / "context.json"
SPEC_FILE  = ROOT / "butterfold_module_io.md"     # the ONLY spec
RTL_DIR    = ROOT / "generated" / "rtl"
TB_DIR     = ROOT / "tests" / "modules"

# Load OPENAI_API_KEY from .env so the ReAct loop is driven when a key exists.
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    pass


def spec_hash() -> str:
    h = hashlib.sha256()
    if SPEC_FILE.exists():
        h.update(SPEC_FILE.read_bytes())
    return h.hexdigest()[:12]


class Journal:
    """Append-only run memory, persisted to generated/context.json. Entries from
    a previous spec version are flagged stale=True so agents can down-weight them."""

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
            e["stale"] = e.get("stale", False) or (prior != self.spec)
            self.entries.append(e)

    def append(self, agent: str, kind: str, summary: str, data: Optional[dict] = None) -> dict:
        entry = {"ts": round(time.time(), 3), "agent": agent, "kind": kind,
                 "summary": summary[:500], "data": data or {}, "stale": False}
        self.entries.append(entry); self.save()
        return entry

    def recent(self, n: int = 12, agent: Optional[str] = None,
               include_stale: bool = False) -> list[dict]:
        items = [e for e in self.entries
                 if (include_stale or not e["stale"])
                 and (agent is None or e["agent"] == agent)]
        return items[-n:]

    def context_block(self, n: int = 12) -> str:
        rows = self.recent(n)
        if not rows:
            return "(no prior context)"
        return "\n".join(f"- [{e['agent']}/{e['kind']}] {e['summary']}" for e in rows)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(
            {"spec_hash": self.spec, "updated": round(time.time(), 3),
             "entries": self.entries}, indent=2), encoding="utf-8")

    def reset(self) -> None:
        self.entries = []; self.save()


def _obs(ok: bool, summary: str, **data) -> dict:
    return {"ok": bool(ok), "summary": summary, "data": data}


class ModuleHarness:
    """ACT surface for authoring ONE module. Bound to a single module name +
    its parsed contract, so the ReAct tools stay small and focused. EDA tools
    (iverilog/yosys) need the Docker container; off-container they return
    ok=False with a clear reason so the harness stays importable/testable."""

    def __init__(self, module: str, contract: str, journal: Optional[Journal] = None,
                 skeleton: str = "", dep_files: Optional[list] = None):
        self.module   = module
        self.contract = contract
        self.skeleton = skeleton
        self.journal  = journal
        self.path     = RTL_DIR / f"{module}.v"
        self.tb       = TB_DIR / f"tb_{module}.v"
        # Already-authored submodule files this module instantiates, so compile /
        # elaborate / testbench can resolve the hierarchy (needed for the top).
        self.dep      = [str(p) for p in (dep_files or []) if pathlib.Path(p).exists()]

    def _log(self, action: str, obs: dict) -> dict:
        if self.journal:
            self.journal.append(self.module, "action", f"{action}: {obs['summary']}",
                                {"action": action, "ok": obs["ok"]})
        return obs

    def _run(self, cmd: list, timeout: int = 300) -> tuple[int, str]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            return r.returncode, (r.stdout + r.stderr)
        except FileNotFoundError:
            return 127, f"tool not found: {cmd[0]} (run inside the Docker container)"
        except subprocess.TimeoutExpired:
            return 124, f"timeout after {timeout}s"

    # ── reasoning inputs ────────────────────────────────────────────────────
    def read_contract(self) -> dict:
        return self._log("read_contract",
                         _obs(True, f"contract for {self.module}", content=self.contract))

    def read_current(self) -> dict:
        if not self.path.exists():
            return self._log("read_current",
                             _obs(True, f"{self.module}.v not written yet; skeleton frame:",
                                  content=self.skeleton))
        txt = self.path.read_text(encoding="utf-8", errors="replace")
        return self._log("read_current", _obs(True, f"{self.module}.v ({len(txt)} chars)", content=txt))

    # ── authoring ───────────────────────────────────────────────────────────
    def write_module(self, content: str) -> dict:
        if f"module {self.module}" not in content:
            return self._log("write_module",
                             _obs(False, f"content must declare `module {self.module}`"))
        RTL_DIR.mkdir(parents=True, exist_ok=True)
        self.path.write_text(content, encoding="utf-8")
        return self._log("write_module", _obs(True, f"wrote {self.module}.v ({len(content)} chars)"))

    # ── checks ──────────────────────────────────────────────────────────────
    def compile(self) -> dict:
        if not self.path.exists():
            return self._log("compile", _obs(False, f"{self.module}.v not written yet"))
        rc, out = self._run(["iverilog", "-g2012", "-Wall", "-t", "null", str(self.path), *self.dep])
        summary = ("syntax OK" if rc == 0 else
                   "iverilog unavailable (need container)" if rc == 127 else "compile errors")
        return self._log("compile", _obs(rc == 0, summary, rc=rc, log=out[-1600:]))

    def elaborate(self) -> dict:
        if not self.path.exists():
            return self._log("elaborate", _obs(False, f"{self.module}.v not written yet"))
        srcs = " ".join([str(self.path), *self.dep])
        script = (f"read_verilog -sv {srcs}; hierarchy -top {self.module} -check; "
                  f"proc; opt -fast; check")
        rc, out = self._run(["yosys", "-q", "-p", script])
        ok = rc == 0 and "ERROR" not in out.upper()
        return self._log("elaborate", _obs(ok, "elaboration OK" if ok else "yosys error",
                                            rc=rc, log=out[-1600:]))

    def run_tb(self) -> dict:
        if not self.tb.exists():
            return self._log("run_tb", _obs(True, f"no testbench for {self.module} (skipped)", skipped=True))
        if not self.path.exists():
            return self._log("run_tb", _obs(False, f"{self.module}.v not written yet"))
        vvp = RTL_DIR / f"_{self.module}_tb.vvp"
        rc, out = self._run(["iverilog", "-g2012", "-o", str(vvp), str(self.tb), str(self.path), *self.dep])
        if rc != 0:
            return self._log("run_tb", _obs(False, "tb compile failed", rc=rc, log=out[-1600:]))
        rc2, out2 = self._run(["vvp", str(vvp)])
        low = out2.lower()
        ok = rc2 == 0 and "error" not in low and "fail" not in low
        return self._log("run_tb", _obs(ok, "testbench passed" if ok else "testbench reported failure",
                                        rc=rc2, log=out2[-1600:]))


# ── ReAct loop ────────────────────────────────────────────────────────────────
_TOOLS = {
    "read_contract": ({}, [], "Read this module's authoritative port/function contract."),
    "read_current":  ({}, [], "Read the current RTL for this module (or the skeleton frame)."),
    "write_module":  ({"content": "string"}, ["content"],
                      "Write the COMPLETE Verilog file for this module (full replace)."),
    "compile":       ({}, [], "iverilog -g2012 syntax check of this module (needs container)."),
    "elaborate":     ({}, [], "Yosys hierarchy+check elaboration of this module (needs container)."),
    "run_tb":        ({}, [], "Compile+run this module's testbench if one exists (needs container)."),
    "done":          ({"status": "string", "summary": "string"}, ["status", "summary"],
                      "Finish: status='success' or 'blocked', with a one-line summary."),
}


def _tool_schemas() -> list:
    out = []
    for name, (props, required, desc) in _TOOLS.items():
        out.append({"type": "function", "function": {
            "name": name, "description": desc,
            "parameters": {"type": "object",
                           "properties": {k: {"type": v} for k, v in props.items()},
                           "required": required}}})
    return out


REACT_SYSTEM = """\
You are a deep RTL engineering agent. You AUTHOR one Verilog-2012 module from its
port contract by reasoning then acting: call tools one at a time, observe each
result, decide the next step.

Rules:
- Implement EXACTLY the ports in the contract: same names, directions, and widths.
  Do not add or drop ports. Keep the module name exactly as given.
- Write real, synthesizable RTL for the module's stated Function. Use synchronous
  logic on posedge clk with active-low rst_n. Drive every output; avoid latches
  and combinational loops. Use valid/ready handshakes where the contract has them.
- Work in a tight loop: write_module with the COMPLETE file, then compile, then
  elaborate, then run_tb. Read the tool log and fix the ACTUAL error before the
  next write. Never write twice without checking in between.
- compile errors mean your last file is wrong — fix that file, don't pile on.
- Prefer a smaller correct implementation over an elaborate broken one. A clean
  elaboration + passing (or absent) testbench is success.
- Every turn call exactly one tool, or call done(). Call done(status='success')
  once it compiles and elaborates cleanly (and run_tb passes or is skipped), or
  done(status='blocked') if truly stuck — always with a short summary."""


def react_loop(goal: str, harness: ModuleHarness, journal: Journal,
               agent: str = "code", model: str = "gpt-4o", max_steps: int = 14) -> dict:
    """think -> act -> observe over a ModuleHarness. Returns
    {"ok","status","steps",...}. With no OPENAI_API_KEY, writes the skeleton and
    returns a fallback result so the pipeline still runs without an LLM."""
    if not os.environ.get("OPENAI_API_KEY"):
        if harness.skeleton:
            harness.write_module(harness.skeleton)
        journal.append(agent, "decision", f"{harness.module}: no API key — wrote skeleton")
        return {"ok": True, "status": "skeleton", "steps": 0, "fallback": True,
                "summary": "no API key: authored compile-clean port skeleton"}

    import openai
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    def _create(**kw):
        wait = 1.0
        for attempt in range(6):
            try:
                return client.chat.completions.create(**kw)
            except openai.RateLimitError:
                if attempt == 5:
                    raise
                time.sleep(wait); wait = min(wait * 2, 20)

    dispatch = {"read_contract": harness.read_contract, "read_current": harness.read_current,
                "write_module": harness.write_module, "compile": harness.compile,
                "elaborate": harness.elaborate, "run_tb": harness.run_tb}
    messages = [
        {"role": "system", "content": REACT_SYSTEM},
        {"role": "user", "content": f"GOAL:\n{goal}\n\nPRIOR CONTEXT:\n{journal.context_block()}"},
    ]

    stalls = 0
    for step in range(1, max_steps + 1):
        resp = _create(model=model, messages=messages, tools=_tool_schemas(),
                       tool_choice="auto", max_tokens=4096)
        msg = resp.choices[0].message

        if not msg.tool_calls:
            stalls += 1
            journal.append(agent, "decision", f"{harness.module}: no tool call (nudge {stalls})")
            if stalls > 2:
                return {"ok": False, "status": "stalled", "steps": step, "reason": "no_tool_call"}
            messages.append({"role": "assistant", "content": msg.content or ""})
            messages.append({"role": "user", "content":
                "You replied with prose. Call exactly one tool now (write_module, compile, "
                "elaborate, run_tb, read_contract), or done() if it already compiles and "
                "elaborates. Take the single next action."})
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
                journal.append(agent, "decision",
                               f"{harness.module}: done [{status}]: {args.get('summary','')}")
                return {"ok": status == "success", "status": status,
                        "steps": step, "summary": args.get("summary", "")}
            fn = dispatch.get(name)
            obs = fn(**args) if fn else _obs(False, f"unknown tool: {name}")
            content = json.dumps(obs)
            # keep code reads intact; cap noisy compile/elaborate logs
            if name not in ("read_current", "read_contract") and len(content) > 1800:
                content = content[:1800] + ' ...TRUNCATED"}'
            messages.append({"role": "tool", "tool_call_id": tc.id, "content": content})

    journal.append(agent, "decision", f"{harness.module}: hit max_steps ({max_steps})")
    return {"ok": False, "status": "max_steps", "steps": max_steps, "reason": "max_steps"}


# ── self-test (host, no API key) ─────────────────────────────────────────────
if __name__ == "__main__":
    import tempfile
    import module_spec
    tmp = pathlib.Path(tempfile.mkdtemp()) / "context.json"
    j = Journal(tmp); j.reset()
    j.append("planner", "plan", "ordered 7 modules")
    j.append("twiddle_source", "action", "wrote skeleton")
    assert len(Journal(tmp).entries) == 2
    print("[agent_core] Journal self-test OK")

    doc = module_spec.parse()
    mod = doc["modules"]["twiddle_source"]
    h = ModuleHarness("twiddle_source", module_spec.contract_text(mod), j,
                      skeleton=module_spec.skeleton(mod))
    assert h.read_contract()["ok"]
    assert h.compile()["ok"] is False        # no RTL yet
    _saved = os.environ.pop("OPENAI_API_KEY", None)
    res = react_loop("author twiddle_source", h, j, agent="twiddle_source")
    assert res.get("fallback") and h.path.exists()
    print(f"[agent_core] no-key fallback wrote {h.path.name} -> {res['status']}")
    if _saved:
        os.environ["OPENAI_API_KEY"] = _saved
    print("[agent_core] self-test OK")
