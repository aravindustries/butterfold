"""
orchestrator.py — ButterFold modular spec->silicon pipeline.

One button, single source of truth (butterfold_module_io.md):

  1. planner        parse the spec -> ordered module build plan
  2. code agent     ReAct-author each module from its port contract
  3. verify         per-module compile/elaborate/testbench + top integration
  4. repair         re-author any module that failed verify (bounded retries)
  5. synth          Yosys full synthesis of the assembled design (GF180 area)
  6. librelane      RTL->GDS signoff  (only if BUTTERFOLD_GDS=1)
  7. summarize      generated/summary.md

No flat generator, no locked kernel, no golden-byte copy: every module is written
from its contract and checked structurally.

Run:  python agents/orchestrator.py
GDS:  BUTTERFOLD_GDS=1 python agents/orchestrator.py
"""
from __future__ import annotations
import os, json, pathlib
import planner, code_agent, verify_agent, synth_agent, agent_core, golden_agent, functional_agent
import module_spec

ROOT    = pathlib.Path(__file__).parent.parent
GEN     = ROOT / "generated"
MAX_REPAIR = 1     # re-author attempts per failing module


def _line(t): print(f"\n[orchestrator] -- {t} " + "-" * max(0, 42 - len(t)))


def _module_failed(rep: dict, name: str) -> bool:
    m = rep.get("modules", {}).get(name)
    if not m:
        return False
    return not (m.get("compile") and m.get("elaborate") and m.get("tb") is not False)


def run() -> dict:
    GEN.mkdir(parents=True, exist_ok=True)
    journal = agent_core.Journal()
    summary = {}

    _line("Step 1: Planner")
    plan = planner.run()
    summary["modules"] = plan["build_order"]

    _line("Step 2: Code agents (author every module)")
    code_agent.run()

    _line("Step 3: Golden models (Phase 1: daisy chain vs whole-chain golden)")
    try:
        golden = golden_agent.run()
        summary["golden_passed"] = golden.get("passed", False)
    except Exception as exc:
        print(f"[golden] skipped ({exc})")
        golden = {"passed": None}
        summary["golden_passed"] = None

    _line("Step 4: Verify (per-module + integration)")
    report = verify_agent.run()

    _line("Step 5: Repair failing modules")
    doc = module_spec.parse()

    def _to_repair(rep: dict) -> list[str]:
        bad = [n for n in doc["order"] if n != "butterfold_top" and _module_failed(rep, n)]
        integ = rep.get("integration", {})
        if not (integ.get("compile") and integ.get("elaborate")):
            bad.append("butterfold_top")   # integration/wiring failure -> re-author the top
        return bad

    failed = _to_repair(report)
    if not failed:
        print("[orchestrator] verify clean — nothing to repair")
    else:
        for attempt in range(1, MAX_REPAIR + 1):
            print(f"[orchestrator] repair attempt {attempt}: re-authoring {failed}")
            for name in failed:
                code_agent.author_module(name, doc, journal)
            report = verify_agent.run()  # re-verify once after re-authoring the batch
            failed = _to_repair(report)
            if not failed:
                break

    _line("Step 6: Functional gate (Phase 2: RTL vs golden, EVM<=2%)")
    try:
        func = functional_agent.run()
        summary["functional"] = {"evm": func.get("evm_percent"),
                                 "passed": func.get("passed"),
                                 "mismatches": func.get("bit_exact_mismatches")}
    except Exception as exc:
        print(f"[functional] skipped ({exc})")
        func = {"passed": None}
        summary["functional"] = {"passed": None}

    _line("Step 7: Synthesis (area/timing)")
    synth = synth_agent.run()
    summary["synth"] = synth.get("metrics", {})

    _line("Step 8: LibreLane RTL->GDS")
    gds = {"skipped": True}
    if os.environ.get("BUTTERFOLD_GDS"):
        import librelane_agent
        gds = librelane_agent.run()
    else:
        print("[librelane] Skipped - set BUTTERFOLD_GDS=1 to run the (long) GDS flow")

    _line("Step 9: Summarize")
    passed = report.get("passed", False)
    summary.update({
        "verify_passed": passed,
        "gds": gds,
        "area_um2": synth.get("metrics", {}).get("chip_area_um2"),
    })
    _write_summary(plan, report, synth, gds, golden, func)
    gtag = {True: "golden OK", False: "golden FAIL", None: "golden n/a"}[summary.get("golden_passed")]
    fev = summary.get("functional", {}).get("evm")
    fpass = summary.get("functional", {}).get("passed")
    ftag = "func n/a" if fpass is None else (f"func PASS EVM={fev}%" if fpass else f"func FAIL EVM={fev}%")
    print(f"\n[orchestrator] RESULT: {'structural PASS' if passed else 'NEEDS WORK'} "
          f"| {gtag} | {ftag}")
    return summary


def _write_summary(plan, report, synth, gds, golden=None, func=None) -> None:
    lines = ["# ButterFold Modular Workflow Summary", "",
             f"- **Spec (single source of truth)**: {plan['spec']}",
             f"- **Modules authored**: {len(plan['build_order'])}", ""]
    if golden is not None:
        c = golden.get("compliance", {})
        gp = golden.get("passed")
        lines += ["## Golden models (Phase 1: daisy chain vs whole-chain golden)",
                  f"- decomposition compliant: {'YES' if gp else ('NO' if gp is not None else 'n/a')}",
                  f"- TX max stage error: {c.get('tx', {}).get('max_err')}",
                  f"- RX max stage error: {c.get('rx', {}).get('max_err')}", ""]
    lines.append("## Per-module verification")
    lines.append("| module | compile | elaborate | testbench |")
    lines.append("|---|---|---|---|")
    for name, m in report.get("modules", {}).items():
        tb = "skip" if m.get("tb") is None else ("pass" if m.get("tb") else "FAIL")
        lines.append(f"| {name} | {'OK' if m.get('compile') else 'XX'} | "
                     f"{'OK' if m.get('elaborate') else 'XX'} | {tb} |")
    integ = report.get("integration", {})
    lines += ["", "## Top integration",
              f"- compile: {'OK' if integ.get('compile') else 'XX'}",
              f"- elaborate: {'OK' if integ.get('elaborate') else 'XX'}", ""]
    if func is not None:
        fp = func.get("passed")
        lines += ["## Functional gate (Phase 2: RTL vs golden)",
                  f"- EVM: {func.get('evm_percent')}%  (gate <= {func.get('evm_gate', 2.0)}%)",
                  f"- bit-exact mismatches: {func.get('bit_exact_mismatches')}/{func.get('total_bytes')}",
                  f"- functional pass: {'YES' if fp else ('NO' if fp is not None else 'n/a')}", ""]
    area = synth.get("metrics", {}).get("chip_area_um2")
    lines += ["## Synthesis", f"- GF180 area: {area} um^2" if area else "- (not run)", ""]
    if gds.get("skipped"):
        lines += ["## GDS", "- not run (set BUTTERFOLD_GDS=1)"]
    else:
        lines += ["## GDS", f"- gds: {gds.get('gds_path')}",
                  f"- DRC: {gds.get('drc_violations')}  LVS: {gds.get('lvs_errors')}"]
    lines += ["", f"**Overall: {'PASSED' if report.get('passed') else 'NEEDS WORK'}**"]
    (GEN / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"[orchestrator] Summary -> {GEN / 'summary.md'}")


if __name__ == "__main__":
    run()
