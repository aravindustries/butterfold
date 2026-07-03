"""
verify_agent.py — modular verification (deterministic, no LLM).

For each authored module: iverilog compile, yosys elaboration (hierarchy+check),
and its testbench if present. Then a TOP INTEGRATION check: elaborate the whole
design with butterfold_top as top over every module file, confirming the modules
wire together and the hierarchy resolves.

There is no flat golden model here — correctness is established structurally
(exact ports, clean elaboration, passing testbenches). This is the honest gate
for hand-authored modular RTL.

Output: generated/verify_report.json ; returns a result dict.
"""
from __future__ import annotations
import json, subprocess, pathlib
import module_spec

ROOT    = pathlib.Path(__file__).parent.parent
RTL_DIR = ROOT / "generated" / "rtl"
TB_DIR  = ROOT / "tests" / "modules"
OUT     = ROOT / "generated" / "verify_report.json"


def _run(cmd: list, timeout: int = 300) -> tuple[int, str]:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr)
    except FileNotFoundError:
        return 127, f"tool not found: {cmd[0]} (run inside the Docker container)"
    except subprocess.TimeoutExpired:
        return 124, f"timeout after {timeout}s"


def _rtl_files() -> list[pathlib.Path]:
    """Only the authored module files — never testbenches (tb_*) or scratch (_*)
    that may linger in the gitignored generated/rtl from earlier runs."""
    names = set(module_spec.parse()["modules"].keys())
    return sorted(RTL_DIR / f"{n}.v" for n in names if (RTL_DIR / f"{n}.v").exists())


def check_module(name: str) -> dict:
    vfile = RTL_DIR / f"{name}.v"
    tb    = TB_DIR / f"tb_{name}.v"
    out   = {"module": name, "present": vfile.exists(),
             "compile": None, "elaborate": None, "tb": None}
    if not vfile.exists():
        out["error"] = "RTL file missing"
        return out

    rc, log = _run(["iverilog", "-g2012", "-Wall", "-t", "null", str(vfile)])
    out["compile"] = (rc == 0)
    out["_compile_log"] = log[-800:] if rc else ""

    script = (f"read_verilog -sv {vfile}; hierarchy -top {name} -check; proc; opt -fast; check")
    rc, log = _run(["yosys", "-q", "-p", script])
    out["elaborate"] = (rc == 0 and "ERROR" not in log.upper())
    out["_elab_log"] = log[-800:] if not out["elaborate"] else ""

    if tb.exists():
        vvp = RTL_DIR / f"_{name}_tb.vvp"
        rc, log = _run(["iverilog", "-g2012", "-o", str(vvp), str(tb), str(vfile)])
        if rc != 0:
            out["tb"] = False; out["_tb_log"] = "tb compile failed: " + log[-600:]
        else:
            rc2, log2 = _run(["vvp", str(vvp)])
            low = log2.lower()
            out["tb"] = (rc2 == 0 and "error" not in low and "fail" not in low)
            out["_tb_log"] = log2[-600:] if not out["tb"] else ""
    return out


def integration_check() -> dict:
    files = [str(p) for p in _rtl_files()]
    if not files:
        return {"present": False, "error": "no RTL files"}
    rc, log = _run(["iverilog", "-g2012", "-Wall", "-t", "null", *files])
    compile_ok = (rc == 0)
    script = ("read_verilog -sv " + " ".join(files) +
              "; hierarchy -top butterfold_top -check; proc; opt -fast; check")
    rc2, log2 = _run(["yosys", "-q", "-p", script])
    elab_ok = (rc2 == 0 and "ERROR" not in log2.upper())
    return {"present": True, "compile": compile_ok, "elaborate": elab_ok,
            "_compile_log": log[-800:] if not compile_ok else "",
            "_elab_log": log2[-800:] if not elab_ok else ""}


def run() -> dict:
    doc = module_spec.parse()
    print("[verify] Per-module checks (compile / elaborate / testbench)...")
    modules = {}
    for name in doc["order"]:
        if name == "butterfold_top":
            continue
        r = check_module(name)
        modules[name] = r
        flag = lambda b: "OK " if b else ("-- " if b is None else "XX ")
        tb = "tb:" + ("skip" if r["tb"] is None else ("pass" if r["tb"] else "FAIL"))
        print(f"[verify]   {name:<28} compile:{flag(r['compile'])} "
              f"elab:{flag(r['elaborate'])} {tb}")

    print("[verify] Top integration check (all modules -> butterfold_top)...")
    integ = integration_check()
    print(f"[verify]   integration   compile:{'OK' if integ.get('compile') else 'XX'} "
          f"elab:{'OK' if integ.get('elaborate') else 'XX'}")

    mod_ok = all(m.get("compile") and m.get("elaborate") and m.get("tb") is not False
                 for m in modules.values())
    passed = mod_ok and bool(integ.get("compile")) and bool(integ.get("elaborate"))
    report = {"passed": passed, "modules": modules, "integration": integ}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"[verify] -- Overall: {'PASSED' if passed else 'FAILED'} --")
    return report


if __name__ == "__main__":
    run()
