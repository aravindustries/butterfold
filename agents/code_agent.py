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
sys.path.insert(0, str(ROOT / "golden"))

_vectors_ready = False


def _ensure_vectors() -> None:
    """Emit the golden vectors once so the FUNCTIONAL testbenches have their
    expected data while the agent authors (the tb run_tb gate reads them)."""
    global _vectors_ready
    if _vectors_ready:
        return
    try:
        import vectors
        vectors.emit()
        _vectors_ready = True
    except Exception as exc:
        print(f"[code_agent] (golden vectors not emitted: {exc})")


def _deps(name: str) -> list[str]:
    import planner
    return planner.DEPENDS.get(name, [])


def _golden_hint(name: str) -> str:
    """Per-module 'translate the golden, don't invent' hint. The functional
    testbench enforces it; the hint makes the target explicit."""
    if name == "twiddle_source":
        try:
            import reference
            re, im = reference.twiddle_rom(reference.K)
            rows = "\n".join(f"  {a}: tw_re={re[a]}, tw_im={im[a]}" for a in range(len(re)))
            return (
                "\n\nIMPLEMENTATION HINT (golden LUT — match exactly):\n"
                "twiddle_source is a ROM of quantized signed Q1.7 (int8) twiddles.\n"
                "For tw_conjugate=0, output EXACTLY these values for tw_addr=0..11:\n"
                f"{rows}\n"
                "For tw_conjugate=1, keep tw_re and NEGATE tw_im (two's complement).\n"
                "Hardcode this as a case statement on tw_addr; do NOT compute trig.\n"
                "Assert tw_valid when the value is presented (a small fixed latency "
                "after tw_req is fine). Addresses >= 12 may return 0.")
        except Exception:
            return ""
    return ""


def _goal(name: str, contract: str, deps: list[str], doc: dict) -> str:
    if not deps:
        return (f"Author the synthesizable Verilog-2012 module `{name}` implementing exactly "
                f"this contract. Match every port name/direction/width.\n\n{contract}")
    # For an integrating module, give the EXACT submodule contracts so it wires
    # real port names (never guessed) and instantiates the modules by name.
    sub = "\n\n".join(module_spec.contract_text(doc["modules"][d]) for d in deps)
    return (f"Author the synthesizable Verilog-2012 module `{name}` implementing exactly "
            f"this contract. Match every port name/direction/width. This is the top: it must "
            f"INSTANTIATE and wire the submodules below using their EXACT port names — do not "
            f"invent ports. The submodule files already exist in generated/rtl and are compiled "
            f"alongside your module, so instantiate them directly.\n\n"
            f"=== THIS MODULE ({name}) CONTRACT ===\n{contract}\n\n"
            f"=== SUBMODULE CONTRACTS TO INSTANTIATE ===\n{sub}")


def author_module(name: str, doc: dict, journal: agent_core.Journal) -> dict:
    _ensure_vectors()
    mod       = doc["modules"][name]
    contract  = module_spec.contract_text(mod)
    skel      = module_spec.skeleton(mod)
    deps      = _deps(name)
    dep_files = [RTL_DIR / f"{d}.v" for d in deps]
    harness   = agent_core.ModuleHarness(name, contract, journal, skeleton=skel,
                                         dep_files=dep_files)

    goal = _goal(name, contract, deps, doc) + _golden_hint(name)
    print(f"[code_agent] authoring {name} ({len(mod['ports'])} ports)...")
    res = agent_core.react_loop(goal, harness, journal, agent=name)

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
