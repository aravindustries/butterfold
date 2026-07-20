"""
orchestrator.py — the LangGraph state graph that wires ButterFold's agents
into the spec-to-GDS pipeline described in README's "Agentic Verilog Design
Workflow":

    plan -> author (ReAct code+debug agent) -> verify -> golden -> functional
          -> synth -> gds (optional) -> report

Each node is one of the sibling agent modules' `run()`; `author` additionally
runs a real LangGraph ReAct loop per module (rtl_react_agent.py) when
BUTTERFOLD_AUTHOR_RTL=1. This file is the answer to "is the orchestration
code available": it IS the orchestration code, plain to read top to bottom,
with no hidden control flow.

Model dependency: whichever provider agents.llm_provider is configured for
(OpenAI, an open-weight model behind an OpenAI-compatible endpoint, or none).
`author` is the only node that can call an LLM at all; every other node
(plan's build order, verify, golden, functional, synth, gds) is a
deterministic script and runs identically with or without one — so the
pipeline is reproducible even with BUTTERFOLD_LLM_PROVIDER=none.

Every run writes generated/logs/run_manifest.json: the exact provider/model/
settings used, which stages ran, and pass/fail per stage — the execution log
for reproducing or auditing a specific run. Per-call LLM prompts/responses go
to generated/logs/llm_calls.jsonl (see llm_provider.py); per-module ReAct
transcripts go to generated/logs/rtl_agent_<module>.json.

Run:
    python agents/orchestrator.py                    # deterministic, no GDS
    BUTTERFOLD_AUTHOR_RTL=1 python agents/orchestrator.py   # LLM authors RTL
    BUTTERFOLD_GDS=1 python agents/orchestrator.py          # + full GDS flow

Env vars affecting which model (if any) the `author` stage uses are documented
in llm_provider.py (BUTTERFOLD_LLM_PROVIDER / _BASE_URL / _MODEL / _API_KEY).
"""
from __future__ import annotations
import os, json, pathlib, time
from typing import TypedDict, Optional

import planner
import verify_agent
import golden_agent
import functional_agent
import synth_agent
import librelane_agent
import llm_provider

ROOT = pathlib.Path(__file__).parent.parent
MANIFEST_PATH = ROOT / "generated" / "logs" / "run_manifest.json"


class PipelineState(TypedDict, total=False):
    plan: dict
    author: dict
    verify: dict
    golden: dict
    functional: dict
    synth: dict
    gds: dict
    stage_times: dict


def _timed(name: str, state: PipelineState, fn):
    t0 = time.time()
    result = fn()
    state.setdefault("stage_times", {})[name] = round(time.time() - t0, 2)
    return result


# ── graph nodes ─────────────────────────────────────────────────────────────

def node_plan(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: plan ===")
    state["plan"] = _timed("plan", state, planner.run)
    return state


def node_author(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: author (RTL code + debug agent) ===")
    if not os.environ.get("BUTTERFOLD_AUTHOR_RTL"):
        state["author"] = {"skipped": "set BUTTERFOLD_AUTHOR_RTL=1 to run the ReAct "
                                       "RTL author+debug agent; otherwise the committed "
                                       "generated/rtl (frozen from rtl/) is used as-is"}
        print(f"[orchestrator] author skipped — {state['author']['skipped']}")
        return state
    import rtl_react_agent
    state["author"] = _timed("author", state, rtl_react_agent.run)
    return state


def node_verify(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: verify (per-module + integration) ===")
    state["verify"] = _timed("verify", state, verify_agent.run)
    return state


def node_golden(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: golden (per-module models vs whole-chain reference) ===")
    state["golden"] = _timed("golden", state, golden_agent.run)
    return state


def node_functional(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: functional (chip-level EVM gate) ===")
    state["functional"] = _timed("functional", state, functional_agent.run)
    return state


def node_synth(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: synth (yosys area/cell estimate) ===")
    state["synth"] = _timed("synth", state, synth_agent.run)
    return state


def node_gds(state: PipelineState) -> PipelineState:
    print("\n=== [orchestrator] stage: gds (LibreLane RTL->GDS, optional) ===")
    state["gds"] = _timed("gds", state, librelane_agent.run)
    return state


def _build_graph():
    from langgraph.graph import StateGraph, END

    g = StateGraph(PipelineState)
    g.add_node("plan", node_plan)
    g.add_node("author", node_author)
    g.add_node("verify", node_verify)
    g.add_node("golden", node_golden)
    g.add_node("functional", node_functional)
    g.add_node("synth", node_synth)
    g.add_node("gds", node_gds)

    g.set_entry_point("plan")
    g.add_edge("plan", "author")
    g.add_edge("author", "verify")
    g.add_edge("verify", "golden")
    g.add_edge("golden", "functional")
    g.add_edge("functional", "synth")
    g.add_edge("synth", "gds")
    g.add_edge("gds", END)
    return g.compile()


def _stage_passed(name: str, s: dict) -> Optional[bool]:
    if s is None or s.get("skipped"):
        return None
    if "passed" in s:
        return bool(s["passed"])
    if name == "gds":
        return bool(s.get("gds_ran"))
    if name == "synth":
        return bool(s.get("synth_ran"))
    if name == "plan":
        return "error" not in s and bool(s.get("subtasks"))
    return None


def run() -> PipelineState:
    graph = _build_graph()
    llm_cfg = llm_provider.active_config()
    print(f"[orchestrator] LLM config: provider={llm_cfg['provider']} "
          f"model={llm_cfg['model']} open_source_model={llm_cfg['open_source_model']}")

    t0 = time.time()
    final_state = graph.invoke({})
    wall_s = round(time.time() - t0, 2)

    manifest = {
        "llm_config": llm_cfg,
        "author_rtl_enabled": bool(os.environ.get("BUTTERFOLD_AUTHOR_RTL")),
        "gds_enabled": bool(os.environ.get("BUTTERFOLD_GDS")),
        "wall_time_s": wall_s,
        "stage_times_s": final_state.get("stage_times", {}),
        "stage_results": {
            name: _stage_passed(name, final_state.get(name))
            for name in ("plan", "author", "verify", "golden", "functional", "synth", "gds")
        },
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print("\n=== [orchestrator] run summary ===")
    for name, ok in manifest["stage_results"].items():
        flag = "SKIP" if ok is None else ("PASS" if ok else "FAIL")
        print(f"  {name:<12} {flag}")
    print(f"[orchestrator] manifest written to {MANIFEST_PATH.relative_to(ROOT)}")
    print(f"[orchestrator] total wall time: {wall_s}s")
    return final_state


if __name__ == "__main__":
    run()
