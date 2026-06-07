"""
Verification Agent — runs iverilog syntax check and optional simulation.
Requires iverilog + vvp to be in PATH (available inside IIC-OSIC-TOOLS Docker).

Input : generated/rtl/butterfold_top.v
        generated/rtl/tb_butterfold_top.v  (optional — simulation skipped if absent)
Output: generated/verify_result.json
        generated/logs/syntax.log
        generated/logs/sim.log             (if simulation ran)
"""
import json, pathlib, subprocess

ROOT        = pathlib.Path(__file__).parent.parent
RTL_FILE    = ROOT / "generated" / "rtl" / "butterfold_top.v"
TB_FILE     = ROOT / "generated" / "rtl" / "tb_butterfold_top.v"
LOG_DIR     = ROOT / "generated" / "logs"
RESULT_FILE = ROOT / "generated" / "verify_result.json"


def _run(cmd, **kwargs):
    return subprocess.run(cmd, capture_output=True, text=True, **kwargs)


def syntax_check(rtl_file):
    r = _run(["iverilog", "-g2012", "-Wall", "-t", "null", str(rtl_file)])
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def simulate(rtl_file, tb_file, log_dir):
    vvp_out = log_dir / "sim.vvp"
    compile_r = _run(["iverilog", "-g2012", "-o", str(vvp_out), str(tb_file), str(rtl_file)])
    if compile_r.returncode != 0:
        return False, (compile_r.stdout + compile_r.stderr).strip()

    sim_r = _run(["vvp", str(vvp_out)], timeout=120)
    output = (sim_r.stdout + sim_r.stderr).strip()
    (log_dir / "sim.log").write_text(output)
    passed = ("PASS" in sim_r.stdout) and (sim_r.returncode == 0)
    return passed, output


def run():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    result = {"syntax_ok": False, "sim_ok": None, "errors": []}

    if not RTL_FILE.exists():
        msg = "RTL file not found — run code_agent.py first"
        print(f"[verify] ERROR: {msg}")
        result["errors"].append(msg)
        RESULT_FILE.write_text(json.dumps(result, indent=2))
        return result

    syntax_ok, syntax_log = syntax_check(RTL_FILE)
    (LOG_DIR / "syntax.log").write_text(syntax_log)
    result["syntax_ok"] = syntax_ok

    if not syntax_ok:
        print(f"[verify] Syntax FAILED:\n{syntax_log}")
        result["errors"].append(syntax_log)
        RESULT_FILE.write_text(json.dumps(result, indent=2))
        return result

    print("[verify] Syntax OK")

    if TB_FILE.exists():
        sim_ok, sim_log = simulate(RTL_FILE, TB_FILE, LOG_DIR)
        result["sim_ok"] = sim_ok
        if not sim_ok:
            print(f"[verify] Simulation FAILED:\n{sim_log}")
            result["errors"].append(sim_log)
        else:
            print("[verify] Simulation PASSED")
    else:
        print(f"[verify] No testbench at {TB_FILE} — skipping simulation")

    RESULT_FILE.write_text(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    run()
