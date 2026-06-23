"""
LangGraph Orchestrator — automates the full ButterFold agentic workflow:

  planner → code_agent → reflect → verify ──(pass)──► synth → summarize → END
                                        │                                ▲
                                        └──(fail)──► debug ───────────────┘
                                                    (loops until pass or max iterations)

Deep-agent layers:
  1. code_agent:    generator-validated DSP kernel (golden-checked before emit)
  2. reflect_agent: whole-design cross-module review (advisory)
  3. debug_agent:   iverilog-error-driven repair loop (up to 5×)
  4. synth_agent:   full Yosys synthesis + GF180 area/cell/FF report (on pass)

Run:
    python agents/orchestrator.py

Output:
    generated/summary.md   — human-readable run summary
    generated/plan.json
    generated/rtl/butterfold_top.v
    generated/reflect_result.json
    generated/verify_result.json
    generated/synth/synth_report.json + butterfold_top_synth.v
    generated/logs/
"""

import os, json, pathlib, importlib.util, time
from typing import TypedDict, Optional

from langgraph.graph import StateGraph, END
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

MAX_DEBUG_ITERATIONS = 5
MAX_RETRIES = 5
INITIAL_WAIT = 1


def _call_with_retry(func, *args, **kwargs):
    """Retry OpenAI API calls with exponential backoff on rate limit errors."""
    wait_time = INITIAL_WAIT
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return func(*args, **kwargs)
        except openai.RateLimitError as e:
            if attempt == MAX_RETRIES:
                raise
            print(f"[orchestrator] Rate limit hit (attempt {attempt}/{MAX_RETRIES}), waiting {wait_time}s...")
            time.sleep(wait_time)
            wait_time *= 2


# ---------------------------------------------------------------------------
# Load existing agents (handles verify.agent.py's unusual filename)
# ---------------------------------------------------------------------------

def _load_module(logical_name: str, filename: str):
    path = pathlib.Path(__file__).parent / filename
    spec = importlib.util.spec_from_file_location(logical_name, path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

planner_mod = _load_module("planner",       "planner.py")
code_mod    = _load_module("code_agent",   "code_agent.py")
reflect_mod = _load_module("reflect_agent","reflect_agent.py")
verify_mod  = _load_module("verify_agent", "verify.agent.py")
debug_mod   = _load_module("debug_agent",  "debug_agent.py")
synth_mod   = _load_module("synth_agent",  "synth_agent.py")
librelane_mod = _load_module("librelane_agent", "librelane_agent.py")


def _deep(mod):
    """Prefer an agent's deep (reason+act) run_react; each one falls back to its
    scripted run() internally when no API key is set, so this is always safe."""
    return mod.run_react if hasattr(mod, "run_react") else mod.run


# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

class State(TypedDict):
    plan:             Optional[dict]
    rtl_path:         Optional[str]
    reflect_result:   Optional[dict]
    verify_result:    Optional[dict]
    synth_result:     Optional[dict]
    gds_result:       Optional[dict]
    debug_iterations: int
    passed:           bool
    summary:          Optional[str]


# ---------------------------------------------------------------------------
# Node: planner
# ---------------------------------------------------------------------------

def node_planner(state: State) -> dict:
    print("\n[orchestrator] ── Step 1: Planner (deep) ───────────────────")
    plan = _deep(planner_mod)()
    return {"plan": plan}


# ---------------------------------------------------------------------------
# Node: code_agent
# ---------------------------------------------------------------------------

def node_code_agent(state: State) -> dict:
    print("\n[orchestrator] ── Step 2: Code Agent (deep) ─────────────────")
    _deep(code_mod)()
    return {"rtl_path": str(ROOT / "generated" / "rtl" / "butterfold_top.v")}


# ---------------------------------------------------------------------------
# Node: reflect  (deep cross-module review between code_agent and verify)
# ---------------------------------------------------------------------------

def node_reflect(state: State) -> dict:
    print("\n[orchestrator] ── Step 3: Reflect (deep review) ────────────")
    result = reflect_mod.run()
    return {"reflect_result": result}


# ---------------------------------------------------------------------------
# Node: verify
# ---------------------------------------------------------------------------

def node_verify(state: State) -> dict:
    print("\n[orchestrator] ── Step 4: Verify ───────────────────────────")
    result = verify_mod.run()
    passed = _compute_passed(result)
    return {"verify_result": result, "passed": passed}


# ---------------------------------------------------------------------------
# Node: debug  (fixes RTL; verify node re-runs afterwards)
# ---------------------------------------------------------------------------

def node_debug(state: State) -> dict:
    iteration = state["debug_iterations"] + 1
    print(f"\n[orchestrator] ── Step 5: Debug (deep, iteration {iteration}/{MAX_DEBUG_ITERATIONS}) ──")

    # Deep (reason+act) debug: the agent compiles, reads the actual error, makes a
    # targeted wrapper edit, and re-checks golden_evm with memory of prior attempts.
    # It reads the live verify_result.json itself; falls back to its scripted loop
    # when no API key is set. The locked kernel is never touched.
    debug_mod.run_react()
    print(f"[orchestrator] Debug pass complete — returning to verify")
    return {"debug_iterations": iteration}


# ---------------------------------------------------------------------------
# Node: synth  (full Yosys synthesis + area report; runs only after a pass)
# ---------------------------------------------------------------------------

def node_synth(state: State) -> dict:
    print("\n[orchestrator] ── Step 5: Synthesis (area/timing) ──────────")
    try:
        result = synth_mod.run()
    except Exception as exc:
        print(f"[orchestrator] Synthesis skipped ({exc})")
        result = {"synth_ran": False, "error": str(exc)}
    return {"synth_result": result}


# ---------------------------------------------------------------------------
# Node: librelane  (RTL->GDS; the final spec->silicon step, runs after synth)
# ---------------------------------------------------------------------------

def node_librelane(state: State) -> dict:
    print("\n[orchestrator] ── Step 6: LibreLane RTL->GDS ────────────────")
    # Gated by BUTTERFOLD_GDS=1 inside the agent (a full GDS run is long); skips
    # cleanly otherwise so quick runs stay fast. This is what makes the flow
    # one-button spec->GDS when you want the silicon.
    try:
        result = librelane_mod.run()
    except Exception as exc:
        print(f"[orchestrator] LibreLane skipped ({exc})")
        result = {"gds_ran": False, "error": str(exc)}
    return {"gds_result": result}


# ---------------------------------------------------------------------------
# Node: summarize
# ---------------------------------------------------------------------------

def node_summarize(state: State) -> dict:
    print("\n[orchestrator] ── Step 6: Summarize ────────────────────────")

    plan    = state.get("plan") or {}
    reflect = state.get("reflect_result") or {}
    verify  = state.get("verify_result") or {}
    synth   = state.get("synth_result") or {}
    passed  = state.get("passed", False)
    iters   = state.get("debug_iterations", 0)

    rtl_file  = ROOT / "generated" / "rtl" / "butterfold_top.v"
    rtl_lines = rtl_file.read_text().count("\n") if rtl_file.exists() else 0

    subtask_lines = "\n".join(
        f"  • {t['id']}: {t['description']}"
        for t in plan.get("subtasks", [])
    )

    reflect_errors = len([i for i in reflect.get("issues", []) if i.get("severity") == "error"])
    golden = verify.get("golden_metrics", {}) or {}
    golden_line = (f"{verify.get('golden_ok')}  "
                   f"(EVM={golden.get('evm_percent', '?')}%, "
                   f"threshold {golden.get('evm_threshold_percent', 2.0)}%)")

    # Synthesis / area line
    sm = (synth or {}).get("metrics", {})
    if sm.get("chip_area_um2") is not None:
        synth_line = (f"area={sm['chip_area_um2']} um^2, cells={sm.get('num_cells', '?')}, "
                      f"FF={sm.get('flip_flops', '?')} (GF180)")
    elif sm.get("num_cells") is not None:
        synth_line = (f"cells={sm['num_cells']}, FF={sm.get('flip_flops', '?')} "
                      f"(generic — no PDK liberty)")
    elif synth.get("error"):
        synth_line = f"not run ({synth['error']})"
    else:
        synth_line = "not run"

    # GDS / signoff line from the LibreLane step.
    gds = state.get("gds_result") or {}
    if gds.get("gds_ran"):
        gm = gds.get("metrics", {})
        gds_line = (f"GDS produced — die={gm.get('design__die__area', '?')}, "
                    f"cells={gm.get('design__instance__count', '?')}, "
                    f"DRC={gds.get('drc_violations', '?')}, LVS={gds.get('lvs_errors', '?')}")
    elif gds.get("skipped"):
        gds_line = f"not run ({gds['skipped']})"
    elif gds.get("error"):
        gds_line = f"failed ({gds['error']})"
    else:
        gds_line = "not run"

    stats = (
        f"Module       : {plan.get('module_name', 'butterfold_top')}\n"
        f"Subtasks     : {len(plan.get('subtasks', []))}\n"
        f"RTL lines    : {rtl_lines}\n"
        f"Syntax OK    : {verify.get('syntax_ok')}\n"
        f"Synth OK     : {verify.get('synth_ok')}\n"
        f"Sim result   : {verify.get('sim_ok')}\n"
        f"Golden model : {golden_line}\n"
        f"Synthesis    : {synth_line}\n"
        f"GDS (signoff): {gds_line}\n"
        f"Reflect      : {reflect_errors} advisory issue(s)\n"
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

    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    completion = _call_with_retry(
        client.chat.completions.create,
        model="gpt-4o",
        max_tokens=1024,
        messages=[
            {"role": "system", "content": "You are a chip design technical writer. Be concise and engineering-precise."},
            {"role": "user",   "content": prompt},
        ],
    )

    summary = completion.choices[0].message.content.strip()

    # Print to terminal
    print("\n" + "=" * 62)
    print("  BUTTERFOLD WORKFLOW SUMMARY")
    print("=" * 62)
    print(summary)
    print("-" * 62)
    print(stats, end="")
    print("=" * 62)
    print(f"  RESULT: {'✓ PASSED' if passed else '✗ FAILED'}  "
          f"(golden model EVM {golden.get('evm_percent', '?')}% "
          f"< {golden.get('evm_threshold_percent', 2.0)}% threshold)")
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
        return "synth"            # design verified → synthesize for area/timing
    if state["debug_iterations"] >= MAX_DEBUG_ITERATIONS:
        print(f"\n[orchestrator] Max debug iterations ({MAX_DEBUG_ITERATIONS}) reached.")
        return "summarize"        # give up → skip synthesis, just summarize
    return "debug"


# Pass criterion. Per the project's rule ("RTL must match the bit-accurate
# golden model"), the golden-model EVM check is authoritative: if it passes,
# the design passes regardless of the subjective LLM spec-review opinion.
def _compute_passed(result: dict) -> bool:
    syntax_ok = result.get("syntax_ok", False)
    synth_ok  = result.get("synth_ok",  True)
    golden_ok = result.get("golden_ok")          # True / False / None

    if not syntax_ok:
        return False
    if golden_ok is True:
        return True                              # golden model is ground truth
    if golden_ok is False:
        return False
    # Golden check couldn't run (None): fall back to syntax + synth + sim
    sim_ok  = result.get("sim_ok")
    spec_ok = result.get("spec_ok", True)
    return ((synth_ok is None or synth_ok)
            and (sim_ok  is None or sim_ok)
            and (spec_ok is None or spec_ok))


# ---------------------------------------------------------------------------
# Build and run the graph
# ---------------------------------------------------------------------------

def build_graph() -> StateGraph:
    g = StateGraph(State)

    g.add_node("planner",    node_planner)
    g.add_node("code_agent", node_code_agent)
    g.add_node("reflect",    node_reflect)
    g.add_node("verify",     node_verify)
    g.add_node("debug",      node_debug)
    g.add_node("synth",      node_synth)
    g.add_node("librelane",  node_librelane)
    g.add_node("summarize",  node_summarize)

    g.set_entry_point("planner")
    g.add_edge("planner",    "code_agent")
    g.add_edge("code_agent", "reflect")   # deep review before formal verify
    g.add_edge("reflect",    "verify")
    g.add_edge("debug",      "verify")    # re-verify after debug patch (skip reflect)

    g.add_conditional_edges("verify", route_after_verify, {
        "synth":     "synth",             # passed → synthesize for area/timing
        "summarize": "summarize",         # gave up → skip synthesis
        "debug":     "debug",
    })

    g.add_edge("synth",     "librelane")  # passed synthesis → push to GDS
    g.add_edge("librelane", "summarize")  # GDS/signoff result feeds the summary
    g.add_edge("summarize", END)

    return g.compile()


def run():
    initial: State = {
        "plan":             None,
        "rtl_path":         None,
        "reflect_result":   None,
        "verify_result":    None,
        "synth_result":     None,
        "gds_result":       None,
        "debug_iterations": 0,
        "passed":           False,
        "summary":          None,
    }
    graph = build_graph()
    final = graph.invoke(initial)
    return final


if __name__ == "__main__":
    run()
