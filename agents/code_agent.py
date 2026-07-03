"""
code_agent.py — modular RTL authoring agent.

For each module in the build order, the deep (ReAct) agent authors the complete
Verilog file from that module's port/function contract (parsed from
butterfold_module_io.md), checking itself with compile / elaborate / testbench
between edits. No flat generator, no locked kernel: every module is written from
its contract.

With no OPENAI_API_KEY, each module falls back to its compile-clean port skeleton
so the pipeline still produces elaborable RTL end-to-end.

Run all modules:      python code_agent.py
Run one module:       python code_agent.py --module twiddle_source
"""
from __future__ import annotations
import sys, pathlib
import module_spec
import agent_core

ROOT    = pathlib.Path(__file__).parent.parent
RTL_DIR = ROOT / "generated" / "rtl"


def _deps(name: str) -> list[str]:
    import planner
    return planner.DEPENDS.get(name, [])


def _goal(name: str, contract: str, deps: list[str]) -> str:
    dep = (f"\nThis module instantiates and wires these already-authored submodules "
           f"(read their files under generated/rtl if needed): {', '.join(deps)}."
           if deps else "")
    return (f"Author the synthesizable Verilog-2012 module `{name}` implementing exactly "
            f"this contract. Match every port name/direction/width.{dep}\n\n{contract}")


def author_module(name: str, doc: dict, journal: agent_core.Journal) -> dict:
    mod      = doc["modules"][name]
    contract = module_spec.contract_text(mod)
    skel     = module_spec.skeleton(mod)
    deps     = _deps(name)
    harness  = agent_core.ModuleHarness(name, contract, journal, skeleton=skel)

    print(f"[code_agent] authoring {name} ({len(mod['ports'])} ports)...")
    res = agent_core.react_loop(_goal(name, contract, deps), harness, journal, agent=name)

    # Safety net: if the agent finished without leaving a file, drop the skeleton
    # so downstream integration/elaboration still has a module.
    if not harness.path.exists():
        harness.write_module(skel)
        res["summary"] = (res.get("summary", "") + " | skeleton written as fallback").strip()
    print(f"[code_agent]   {name}: {res.get('status','?')} "
          f"({res.get('summary','').strip()[:80]})")
    return res


def run(only: str | None = None) -> dict:
    doc     = module_spec.parse()
    journal = agent_core.Journal()
    order   = [only] if only else doc["order"]
    results = {}
    for name in order:
        if name not in doc["modules"]:
            print(f"[code_agent] unknown module: {name}"); continue
        results[name] = author_module(name, doc, journal)
    ok = sum(1 for r in results.values() if r.get("ok"))
    print(f"[code_agent] authored {len(results)} module(s); {ok} reached success status")
    return {"results": results, "rtl_dir": str(RTL_DIR)}


def run_react(only: str | None = None) -> dict:
    return run(only)


if __name__ == "__main__":
    only = None
    if "--module" in sys.argv:
        only = sys.argv[sys.argv.index("--module") + 1]
    run(only)
