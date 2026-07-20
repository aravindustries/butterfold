"""
rtl_react_agent.py — the Verilog Code Agent + Verification & Debug Agent from
README's "Agentic Verilog Design Workflow", implemented for real as a
LangGraph ReAct agent (langgraph.prebuilt.create_react_agent): the model
reasons, calls tools (read the contract, write RTL, compile+elaborate+
testbench it), reads the result, and repairs its own output — a closed
author -> check -> repair loop, not a single scripted call.

Model-agnostic: whatever agents.llm_provider.get_llm() returns (OpenAI or an
open-weight model behind an OpenAI-compatible endpoint) drives the loop. With
no LLM configured, author_module() falls back to module_spec's deterministic
skeleton — same no-API-key-required guarantee as the rest of this package.

Output per module: generated/rtl/<module>.v (only written if BUTTERFOLD_AUTHOR_RTL=1,
see orchestrator.py — the committed rtl/ verified snapshot is otherwise left
untouched so PPA/GDS numbers stay reproducible without a live LLM).
Every reasoning/tool-call step is logged by llm_provider to
generated/logs/llm_calls.jsonl; the final transcript per module is written to
generated/logs/rtl_agent_<module>.json.
"""
from __future__ import annotations
import json, pathlib
from typing import Optional

import module_spec
import helpers
import verify_agent
import llm_provider

ROOT = pathlib.Path(__file__).parent.parent
RTL_DIR = ROOT / "generated" / "rtl"
LOG_DIR = ROOT / "generated" / "logs"

MAX_REACT_STEPS = 8  # bounded author -> check -> repair loop per module

SYSTEM_PROMPT = """You are the ButterFold Verilog Code Agent, one stage of an \
agentic spec-to-GDS hardware workflow.

Fixed-point/system conventions (from butterfold_module_io.md):
  - Frequency-domain samples: signed Q1.7 (8-bit, scale 127).
  - Time-domain / scratch-memory samples: signed Q5.11 (16-bit).
  - K=12 active subcarriers, M=128 point FFT/IFFT, CP length 9 or 10, centered
    subcarrier map starting at bin 58.
  - Verilog-2012, `default_nettype none`, synchronous active-low reset (rst_n).

Rules:
  1. The port list given to you by get_module_contract is AUTHORITATIVE. Do not
     add, remove, rename, or resize any port.
  2. Use write_rtl to save your implementation, then ALWAYS call check_module
     to compile, elaborate, and (if a testbench exists) simulate it.
  3. If check_module reports a failure, read the log it returns, fix the RTL,
     and call write_rtl + check_module again. You may use get_helper_contract
     for shared building blocks (complex_mul, butterfly) if the module needs them.
  4. Stop as soon as check_module reports compile=true, elaborate=true, and
     tb is true or null (null means no testbench exists for this module, which
     is a pass by omission).
  5. Do not fabricate a passing result — only trust the literal output of
     check_module.
"""


def _read_current(module: str) -> str:
    p = RTL_DIR / f"{module}.v"
    return p.read_text(encoding="utf-8") if p.exists() else ""


def _build_tools():
    from langchain_core.tools import tool

    @tool
    def get_module_contract(module: str) -> str:
        """Return the authoritative function + port contract for a ButterFold
        module (from butterfold_module_io.md). Call this first."""
        doc = module_spec.parse()
        if module not in doc["modules"]:
            return f"ERROR: unknown module {module!r}. Known: {list(doc['modules'])}"
        return module_spec.contract_text(doc["modules"][module])

    @tool
    def get_helper_contract(name: str) -> str:
        """Return the contract for a shared internal building block
        ('complex_mul' or 'butterfly') usable inside a module's implementation."""
        if not helpers.is_helper(name):
            return f"ERROR: unknown helper {name!r}. Known: {helpers.names()}"
        return helpers.contract_text(name)

    @tool
    def read_current_rtl(module: str) -> str:
        """Read the RTL currently saved for this module (empty string if none
        has been written yet, or a compile-clean port skeleton as a starting
        frame)."""
        cur = _read_current(module)
        if cur:
            return cur
        doc = module_spec.parse()
        if module in doc["modules"]:
            return module_spec.skeleton(doc["modules"][module])
        return ""

    @tool
    def write_rtl(module: str, verilog_code: str) -> str:
        """Save Verilog source as the implementation of `module`. Overwrites
        any previous attempt for this module."""
        RTL_DIR.mkdir(parents=True, exist_ok=True)
        (RTL_DIR / f"{module}.v").write_text(verilog_code, encoding="utf-8")
        return f"wrote {len(verilog_code)} bytes to generated/rtl/{module}.v"

    @tool
    def check_module(module: str) -> str:
        """Compile (iverilog), elaborate (yosys hierarchy+check), and — if a
        testbench exists — simulate the module just written. Returns a JSON
        summary with compile/elaborate/tb booleans and, on failure, the last
        part of the relevant tool log so you can fix the RTL."""
        r = verify_agent.check_module(module)
        summary = {"module": module, "present": r["present"],
                   "compile": r["compile"], "elaborate": r["elaborate"], "tb": r["tb"]}
        for key in ("_compile_log", "_elab_log", "_tb_log"):
            if r.get(key):
                summary[key] = r[key][-500:]
        return json.dumps(summary)

    return [get_module_contract, get_helper_contract, read_current_rtl, write_rtl, check_module]


def _passed(check: dict) -> bool:
    return bool(check.get("compile")) and bool(check.get("elaborate")) and check.get("tb") is not False


def author_module(module: str, llm=None) -> dict:
    """Author (or repair) one module's RTL. Returns
    {module, llm_used, passed, steps, check} — `check` is verify_agent's own
    authoritative result, never the model's self-report."""
    doc = module_spec.parse()
    if module not in doc["modules"]:
        return {"module": module, "error": f"unknown module {module!r}"}

    if llm is None:
        # Deterministic, no-LLM fallback: the compile-clean port skeleton.
        RTL_DIR.mkdir(parents=True, exist_ok=True)
        (RTL_DIR / f"{module}.v").write_text(module_spec.skeleton(doc["modules"][module]),
                                              encoding="utf-8")
        check = verify_agent.check_module(module)
        return {"module": module, "llm_used": False, "passed": _passed(check),
                "steps": 0, "check": {k: v for k, v in check.items() if not k.startswith("_")}}

    from langgraph.prebuilt import create_react_agent
    from langchain_core.messages import HumanMessage

    agent = create_react_agent(llm, _build_tools(), prompt=SYSTEM_PROMPT)
    task = (f"Implement module `{module}` per its contract, then verify it with "
            f"check_module until it passes.\n\n" + module_spec.contract_text(doc["modules"][module]))

    config = {**llm_provider.callbacks_config(), "recursion_limit": MAX_REACT_STEPS * 2 + 4}
    try:
        result = agent.invoke({"messages": [HumanMessage(content=task)]}, config=config)
        messages = result.get("messages", [])
    except Exception as exc:
        messages = []
        print(f"[rtl_react_agent] {module}: agent loop raised {exc!r}")

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    transcript = [{"type": m.__class__.__name__, "content": getattr(m, "content", "")} for m in messages]
    (LOG_DIR / f"rtl_agent_{module}.json").write_text(json.dumps(transcript, indent=2), encoding="utf-8")

    # Authoritative result comes from re-running the check ourselves, not from
    # trusting the agent's last message.
    check = verify_agent.check_module(module)
    passed = _passed(check)
    if not passed:
        print(f"[rtl_react_agent] {module}: LLM-authored RTL did not pass after "
              f"the react loop — falling back to the deterministic skeleton")
        RTL_DIR.mkdir(parents=True, exist_ok=True)
        (RTL_DIR / f"{module}.v").write_text(module_spec.skeleton(doc["modules"][module]),
                                              encoding="utf-8")
        check = verify_agent.check_module(module)
        passed = _passed(check)

    return {"module": module, "llm_used": True, "passed": passed, "steps": len(messages),
            "check": {k: v for k, v in check.items() if not k.startswith("_")}}


def run(modules: Optional[list[str]] = None) -> dict:
    doc = module_spec.parse()
    targets = modules or [n for n in doc["order"] if n != "butterfold_top"]
    llm = llm_provider.get_llm()
    cfg = llm_provider.active_config()
    print(f"[rtl_react_agent] provider={cfg['provider']} model={cfg['model']} "
          f"open_source={cfg['open_source_model']}")

    results = {}
    for name in targets:
        print(f"[rtl_react_agent] authoring {name} ...")
        r = author_module(name, llm=llm)
        results[name] = r
        print(f"[rtl_react_agent]   {name:<28} llm={r.get('llm_used')} "
              f"steps={r.get('steps')} -> {'PASS' if r.get('passed') else 'FAIL'}")

    report = {"provider_config": cfg, "modules": results,
              "passed": all(r.get("passed") for r in results.values())}
    (ROOT / "generated" / "rtl_agent_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


if __name__ == "__main__":
    run()
