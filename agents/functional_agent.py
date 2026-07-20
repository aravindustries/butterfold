"""
functional_agent.py — Phase 2 functional gate.

Emits the golden vectors, runs the top-level functional testbench (drives the chip
with the golden TX input and captures dout), and scores the captured output against
the golden with EVM (authoritative gate <= 2%) plus a bit-exact mismatch count.

This is what makes "the agent-authored RTL actually does the DFT" a measurable
claim. Until the RTL is functional, it reports the shortfall honestly.

Output: generated/functional_report.json ; returns a result dict.
"""
from __future__ import annotations
import json, subprocess, pathlib, sys
import module_spec

ROOT    = pathlib.Path(__file__).parent.parent
RTL_DIR = ROOT / "generated" / "rtl"
TB      = ROOT / "tests" / "tb_top_golden.v"
GOLD    = ROOT / "tests" / "vectors" / "top_gold.hex"
OUT_HEX = RTL_DIR / "top_out.hex"
REPORT  = ROOT / "generated" / "functional_report.json"

sys.path.insert(0, str(ROOT / "golden"))


def _rtl_files() -> list[str]:
    names = module_spec.parse()["modules"].keys()
    return [str(RTL_DIR / f"{n}.v") for n in names if (RTL_DIR / f"{n}.v").exists()]


def _run(cmd, timeout=300):
    try:
        r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr)
    except FileNotFoundError:
        return 127, f"tool not found: {cmd[0]} (need the container)"
    except subprocess.TimeoutExpired:
        return 124, f"timeout after {timeout}s"


def run() -> dict:
    import vectors, evm_check
    result = {"ran": False, "passed": None}

    vectors.emit()
    files = _rtl_files()
    if not files or not (RTL_DIR / "butterfold_top.v").exists():
        result["error"] = "RTL not found — run code_agent first"
        print(f"[functional] {result['error']}")
        return result

    vvp = RTL_DIR / "_top_golden.vvp"
    rc, log = _run(["iverilog", "-g2012", "-o", str(vvp), str(TB), *files])
    if rc != 0:
        result["error"] = "top functional tb failed to compile"
        result["log"] = log[-1200:]
        print(f"[functional] tb compile failed:\n{log[-600:]}")
        return result

    rc, log = _run(["vvp", str(vvp)])
    cap = [ln for ln in log.splitlines() if "captured" in ln or "TIMEOUT" in ln]
    if cap:
        print(f"[functional] {cap[-1].strip()}")

    if not OUT_HEX.exists():
        result["error"] = "no output captured"
        print("[functional] no output produced by the design")
        return result

    score = evm_check.score(str(OUT_HEX), str(GOLD))
    result.update({"ran": True, **score})
    REPORT.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"[functional] EVM={score['evm_percent']}%  gate<={score['evm_gate']}%  "
          f"bit-exact mismatches={score['bit_exact_mismatches']}/{score['total_bytes']}  "
          f"-> {'PASS' if score['passed'] else 'FAIL'}")
    return result


if __name__ == "__main__":
    run()
