"""
LangGraph Orchestrator — automates the full ButterFold agentic workflow:

  planner → code_agent → verify ──(pass)──► summarize → END
                              │                 ▲
                              └──(fail)──► debug ─┘
                                           (loops until pass or max iterations)

Run:
    python agents/orchestrator.py

Output:
    generated/summary.md   — human-readable run summary
    generated/plan.json
    generated/rtl/butterfold_top.v
    generated/verify_result.json
    generated/logs/
"""

import os, json, pathlib, importlib.util
from typing import TypedDict, Optional

from langgraph.graph import StateGraph, END
import anthropic
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

MAX_DEBUG_ITERATIONS = 5


# ---------------------------------------------------------------------------
# Load existing agents (handles verify.agent.py's unusual filename)
# ---------------------------------------------------------------------------

def _load_module(logical_name: str, filename: str):
    path = pathlib.Path(__file__).parent / filename
    spec = importlib.util.spec_from_file_location(logical_name, path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

planner_mod = _load_module("planner",      "planner.py")
code_mod    = _load_module("code_agent",   "code_agent.py")
verify_mod  = _load_module("verify_agent", "verify.agent.py")


# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

class State(TypedDict):
    plan:             Optional[dict]
    rtl_path:         Optional[str]
    verify_result:    Optional[dict]
    debug_iterations: int
    passed:           bool
    summary:          Optional[str]


# ---------------------------------------------------------------------------
# Node: planner
# ---------------------------------------------------------------------------

def node_planner(state: State) -> dict:
    print("\n[orchestrator] ── Step 1: Planner ──────────────────────────")
    plan = planner_mod.run()
    return {"plan": plan}


# ---------------------------------------------------------------------------
# Node: code_agent
# ---------------------------------------------------------------------------

def node_code_agent(state: State) -> dict:
    print("\n[orchestrator] ── Step 2: Code Agent ───────────────────────")
    code_mod.run()
    return {"rtl_path": str(ROOT / "generated" / "rtl" / "butterfold_top.v")}


# ---------------------------------------------------------------------------
# Node: verify
# ---------------------------------------------------------------------------

def node_verify(state: State) -> dict:
    print("\n[orchestrator] ── Step 3: Verify ───────────────────────────")
    result = verify_mod.run()
    passed = _compute_passed(result)
    return {"verify_result": result, "passed": passed}


# ---------------------------------------------------------------------------
# Node: debug  (fixes RTL; verify node re-runs afterwards)
# ---------------------------------------------------------------------------

def node_debug(state: State) -> dict:
    iteration = state["debug_iterations"] + 1
    print(f"\n[orchestrator] ── Step 4: Debug (iteration {iteration}/{MAX_DEBUG_ITERATIONS}) ──")

    errors     = "\n".join(state["verify_result"].get("errors", [])    or ["unknown error"])
    fix_hints  = "\n".join(state["verify_result"].get("fix_hints", []) or [])
    spec_issues = "\n".join(
        f"[{i.get('severity','?').upper()}] {i.get('description','')}"
        for i in state["verify_result"].get("spec_issues", [])
        if i.get("severity") == "error"
    )
    rtl_file = ROOT / "generated" / "rtl" / "butterfold_top.v"
    spec     = (ROOT / "modular_description.md").read_text()
    rtl      = rtl_file.read_text()

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    msg = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=8192,
        system=(
            "You are a Verilog RTL debug agent. "
            "Fix only what the errors indicate. "
            "Preserve all port names, module names, and parameter values exactly. "
            "Keep synthesizability rules: no initial blocks in RTL, no $display/$finish, "
            "synchronous rst_n, posedge clk flip-flops, fixed-point arithmetic only. "
            "Return ONLY the corrected Verilog — no markdown fences, no explanation."
        ),
        messages=[{
            "role": "user",
            "content": (
                f"Original specification:\n{spec}\n\n"
                f"Current RTL:\n{rtl}\n\n"
                f"Verification errors:\n{errors}\n\n"
                + (f"Spec compliance issues:\n{spec_issues}\n\n" if spec_issues else "")
                + (f"Suggested fix hints:\n{fix_hints}\n\n" if fix_hints else "")
                + "Return the corrected Verilog."
            ),
        }],
    )

    fixed = msg.content[0].text.strip()
    if "```" in fixed:
        fixed = fixed.split("```", 1)[1]
        if fixed.lower().startswith(("verilog", "systemverilog", "sv")):
            fixed = fixed.split("\n", 1)[1]
        fixed = fixed.rsplit("```", 1)[0].strip()

    rtl_file.write_text(fixed)
    print(f"[orchestrator] RTL patched — returning to verify")
    return {"debug_iterations": iteration}


# ---------------------------------------------------------------------------
# Node: summarize
# ---------------------------------------------------------------------------

def node_summarize(state: State) -> dict:
    print("\n[orchestrator] ── Step 5: Summarize ────────────────────────")

    plan    = state.get("plan") or {}
    verify  = state.get("verify_result") or {}
    passed  = state.get("passed", False)
    iters   = state.get("debug_iterations", 0)

    rtl_file  = ROOT / "generated" / "rtl" / "butterfold_top.v"
    rtl_lines = rtl_file.read_text().count("\n") if rtl_file.exists() else 0

    subtask_lines = "\n".join(
        f"  • {t['id']}: {t['description']}"
        for t in plan.get("subtasks", [])
    )

    stats = (
        f"Module       : {plan.get('module_name', 'butterfold_top')}\n"
        f"Subtasks     : {len(plan.get('subtasks', []))}\n"
        f"RTL lines    : {rtl_lines}\n"
        f"Syntax OK    : {verify.get('syntax_ok')}\n"
        f"Sim result   : {verify.get('sim_ok')}\n"
        f"Debug iters  : {iters}\n"
        f"Final status : {'✓ PASSED' if passed else '✗ FAILED'}\n"
    )

    remaining_errors = ""
    if not passed and verify.get("errors"):
        remaining_errors = "\nRemaining errors (first 3):\n" + "\n".join(
            str(e)[:300] for e in verify["errors"][:3]
        )

    prompt = (
        "Summarize this ButterFold agentic IC design run in 4–6 bullet points.\n"
        "Cover: what was designed, how many subtasks, RTL quality, verification outcome, "
        "debug effort, and next recommended step.\n\n"
        f"Run statistics:\n{stats}"
        f"{remaining_errors}"
        f"\nSubtasks planned:\n{subtask_lines}"
    )

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    msg = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=1024,
        system="You are a chip design technical writer. Be concise and engineering-precise.",
        messages=[{"role": "user", "content": prompt}],
    )

    summary = msg.content[0].text.strip()

    # Print to terminal
    print("\n" + "=" * 62)
    print("  BUTTERFOLD WORKFLOW SUMMARY")
    print("=" * 62)
    print(summary)
    print("=" * 62)

    # Save to file
    summary_path = ROOT / "generated" / "summary.md"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        f"# ButterFold Workflow Summary\n\n"
        f"{summary}\n\n"
        f"---\n\n"
        f"**Raw run statistics:**\n```\n{stats}```\n"
    )
    print(f"\n[orchestrator] Summary saved → {summary_path}")

    return {"summary": summary}


# ---------------------------------------------------------------------------
# Routing logic
# ---------------------------------------------------------------------------

def route_after_verify(state: State) -> str:
    if state["passed"]:
        return "summarize"
    if state["debug_iterations"] >= MAX_DEBUG_ITERATIONS:
        print(f"\n[orchestrator] Max debug iterations ({MAX_DEBUG_ITERATIONS}) reached.")
        return "summarize"
    return "debug"


# Update the passed flag to require all four verify stages
def _compute_passed(result: dict) -> bool:
    syntax_ok = result.get("syntax_ok", False)
    spec_ok   = result.get("spec_ok",   True)   # None = not run
    synth_ok  = result.get("synth_ok",  True)
    sim_ok    = result.get("sim_ok")             # None = no TB
    return (syntax_ok
            and (spec_ok  is None or spec_ok)
            and (synth_ok is None or synth_ok)
            and (sim_ok   is None or sim_ok))


# ---------------------------------------------------------------------------
# Build and run the graph
# ---------------------------------------------------------------------------

def build_graph() -> StateGraph:
    g = StateGraph(State)

    g.add_node("planner",    node_planner)
    g.add_node("code_agent", node_code_agent)
    g.add_node("verify",     node_verify)
    g.add_node("debug",      node_debug)
    g.add_node("summarize",  node_summarize)

    g.set_entry_point("planner")
    g.add_edge("planner",    "code_agent")
    g.add_edge("code_agent", "verify")
    g.add_edge("debug",      "verify")   # always re-verify after a debug patch

    g.add_conditional_edges("verify", route_after_verify, {
        "summarize": "summarize",
        "debug":     "debug",
    })

    g.add_edge("summarize", END)

    return g.compile()


def run():
    initial: State = {
        "plan":             None,
        "rtl_path":         None,
        "verify_result":    None,
        "debug_iterations": 0,
        "passed":           False,
        "summary":          None,
    }
    graph = build_graph()
    final = graph.invoke(initial)
    return final


if __name__ == "__main__":
    run()
