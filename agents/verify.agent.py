"""
Verification Agent — multi-stage RTL verification pipeline.

Stages (in order):
  1. Syntax check      — iverilog -g2012 -Wall -t null
  2. Spec review       — LLM reads RTL + spec, flags missing/wrong logic
  3. Yosys synthesis   — catches structural issues syntax check misses
  4. Testbench         — auto-generate if none exists, then simulate with vvp
  5. Sim log analysis  — LLM reads simulation output and classifies failures

Requires iverilog, vvp, yosys to be in PATH (inside IIC-OSIC-TOOLS Docker).

Input : generated/rtl/butterfold_top.v   + modular_description.md
Output: generated/verify_result.json
        generated/logs/syntax.log
        generated/logs/synth.log
        generated/logs/sim.log
"""

import os, json, pathlib, subprocess, textwrap
import anthropic
from dotenv import load_dotenv

ROOT        = pathlib.Path(__file__).parent.parent
RTL_FILE    = ROOT / "generated" / "rtl" / "butterfold_top.v"
SPEC_PATH   = ROOT / "modular_description.md"
LOG_DIR     = ROOT / "generated" / "logs"
RTL_DIR     = ROOT / "generated" / "rtl"
RESULT_FILE = ROOT / "generated" / "verify_result.json"

# Prefer the committed testbench in tests/; fall back to agent-generated one
_TB_COMMITTED = ROOT / "tests" / "tb_butterfold_top.v"
_TB_GENERATED = RTL_DIR / "tb_butterfold_top.v"

load_dotenv(ROOT / ".env")


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _run(cmd, timeout=120, **kwargs):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kwargs)


def _llm(system: str, user: str, max_tokens: int = 2048) -> str:
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    msg = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=max_tokens,
        system=system,
        messages=[{"role": "user", "content": user}],
    )
    return msg.content[0].text.strip()


# ─── Stage 1: Syntax check ────────────────────────────────────────────────────

def stage_syntax(rtl_file: pathlib.Path) -> tuple[bool, str]:
    """iverilog syntax-only pass with all warnings enabled."""
    r = _run(["iverilog", "-g2012", "-Wall", "-t", "null", str(rtl_file)])
    log = (r.stdout + r.stderr).strip()
    (LOG_DIR / "syntax.log").write_text(log)
    ok = r.returncode == 0
    print(f"[verify] Stage 1 — Syntax: {'OK' if ok else 'FAILED'}")
    return ok, log


# ─── Stage 2: LLM spec compliance review ─────────────────────────────────────

SPEC_REVIEW_SYSTEM = textwrap.dedent("""\
    You are a senior RTL verification engineer reviewing AI-generated Verilog.
    You will be given a hardware specification and the generated RTL.

    Your job: identify concrete discrepancies between what the spec requires
    and what the RTL actually implements.

    Focus on:
    - Missing or wrong port names / widths
    - Missing processing stages (e.g. missing CP insertion, wrong transform order)
    - Wrong parameter values (K, M, bit widths)
    - FSM states that don't cover required modes (TX / RX)
    - Signals that are declared but never driven (or driven but never used)
    - Synthesizability violations (initial blocks, real types, $display in RTL)
    - Incorrect reset polarity or clock edge

    Output format — return a JSON object:
    {
      "spec_ok": true | false,
      "issues": [
        {"severity": "error|warning", "description": "...", "line_hint": "..."}
      ],
      "summary": "one-sentence overall verdict"
    }
    Return ONLY valid JSON, no explanation outside it.
""")


def stage_spec_review(rtl_file: pathlib.Path, spec_path: pathlib.Path) -> tuple[bool, list, str]:
    """Ask Claude to compare RTL against spec and return structured findings."""
    print("[verify] Stage 2 — LLM spec review ...")
    spec = spec_path.read_text()
    rtl  = rtl_file.read_text()

    raw = _llm(
        system=SPEC_REVIEW_SYSTEM,
        user=f"SPECIFICATION:\n{spec}\n\nGENERATED RTL:\n{rtl}",
        max_tokens=2048,
    )

    # Strip fences if model wrapped in markdown
    if "```" in raw:
        raw = raw.split("```", 1)[1]
        if raw.lower().startswith("json"):
            raw = raw.split("\n", 1)[1]
        raw = raw.rsplit("```", 1)[0].strip()

    try:
        review = json.loads(raw)
    except json.JSONDecodeError:
        review = {"spec_ok": False, "issues": [{"severity": "error",
                  "description": "LLM returned unparseable response", "line_hint": ""}],
                  "summary": raw[:300]}

    (LOG_DIR / "spec_review.json").write_text(json.dumps(review, indent=2))

    errors   = [i for i in review.get("issues", []) if i.get("severity") == "error"]
    warnings = [i for i in review.get("issues", []) if i.get("severity") == "warning"]
    spec_ok  = review.get("spec_ok", False)

    print(f"[verify]   Spec OK: {spec_ok} | errors: {len(errors)} | warnings: {len(warnings)}")
    print(f"[verify]   {review.get('summary', '')}")
    for iss in errors[:3]:
        print(f"[verify]   ERROR: {iss['description']}")
    for iss in warnings[:3]:
        print(f"[verify]   WARN:  {iss['description']}")

    return spec_ok, review.get("issues", []), review.get("summary", "")


# ─── Stage 3: Yosys synthesis check ──────────────────────────────────────────

YOSYS_SCRIPT = """\
read_verilog -sv {rtl}
synth -top butterfold_top -flatten
stat
"""


def stage_yosys(rtl_file: pathlib.Path) -> tuple[bool, str]:
    """
    Run Yosys synthesis. Catches things iverilog misses:
    multi-driven nets, undeclared signals after elaboration, unresolved hierarchies.
    """
    print("[verify] Stage 3 — Yosys synthesis check ...")
    script = YOSYS_SCRIPT.format(rtl=str(rtl_file))
    try:
        r = _run(["yosys", "-p", script], timeout=120)
    except FileNotFoundError:
        print("[verify]   Yosys not found — skipping synthesis check")
        return True, "yosys not available"

    log = (r.stdout + r.stderr).strip()
    (LOG_DIR / "synth.log").write_text(log)
    ok = r.returncode == 0 and "ERROR" not in log.upper()
    print(f"[verify]   Yosys: {'OK' if ok else 'FAILED'}")
    if not ok:
        # Print first error line
        for line in log.splitlines():
            if "error" in line.lower():
                print(f"[verify]   {line.strip()}")
                break
    return ok, log


# ─── Stage 4a: Auto-generate testbench if none exists ────────────────────────

TB_GEN_SYSTEM = textwrap.dedent("""\
    You are a Verilog testbench generation agent.
    Given a hardware spec and the RTL module, generate a self-checking
    simulation testbench that:
    - Instantiates the DUT with correct port connections
    - Applies reset, then tests TX mode and RX mode
    - Checks that dout_valid fires, busy asserts, done asserts
    - Sends all-zero input and checks all-zero output
    - Prints PASS or FAIL to stdout (simulator checks for the word PASS)
    - Uses $dumpfile / $dumpvars for waveform capture to generated/logs/sim.vcd
    - Has a watchdog timeout to prevent infinite hang

    Rules:
    - Use `timescale 1ns/1ps
    - Use iverilog-compatible Verilog 2012 syntax
    - No SystemVerilog-only constructs (no logic type, no always_ff)
    - Return ONLY the Verilog — no explanation, no markdown fences
""")


def stage_gen_testbench(rtl_file: pathlib.Path, spec_path: pathlib.Path) -> pathlib.Path:
    """Generate a testbench via LLM and save to generated/rtl/."""
    print("[verify] Stage 4a — Auto-generating testbench ...")
    spec = spec_path.read_text()
    rtl  = rtl_file.read_text()

    tb_code = _llm(
        system=TB_GEN_SYSTEM,
        user=f"SPECIFICATION:\n{spec}\n\nRTL MODULE:\n{rtl}",
        max_tokens=4096,
    )

    if tb_code.startswith("```"):
        tb_code = tb_code.split("```", 1)[1]
        if tb_code.lower().startswith(("verilog", "sv")):
            tb_code = tb_code.split("\n", 1)[1]
        tb_code = tb_code.rsplit("```", 1)[0].strip()

    tb_path = RTL_DIR / "tb_butterfold_top.v"
    tb_path.write_text(tb_code)
    print(f"[verify]   Testbench written to {tb_path.relative_to(ROOT)}")
    return tb_path


# ─── Stage 4b: Simulation ─────────────────────────────────────────────────────

def stage_simulate(rtl_file: pathlib.Path, tb_file: pathlib.Path) -> tuple[bool, str]:
    """Compile with iverilog and run with vvp."""
    print(f"[verify] Stage 4b — Simulation (tb: {tb_file.relative_to(ROOT)}) ...")
    vvp_out   = LOG_DIR / "sim.vvp"
    compile_r = _run(["iverilog", "-g2012", "-o", str(vvp_out), str(tb_file), str(rtl_file)])
    if compile_r.returncode != 0:
        log = (compile_r.stdout + compile_r.stderr).strip()
        print(f"[verify]   Compile FAILED:\n{log}")
        return False, log

    sim_r  = _run(["vvp", str(vvp_out)], timeout=300)
    output = (sim_r.stdout + sim_r.stderr).strip()
    (LOG_DIR / "sim.log").write_text(output)
    passed = "PASS" in sim_r.stdout and sim_r.returncode == 0
    print(f"[verify]   Simulation: {'PASSED' if passed else 'FAILED'}")
    if not passed:
        # Print last 10 lines for quick diagnosis
        tail = "\n".join(output.splitlines()[-10:])
        print(f"[verify]   --- sim output tail ---\n{tail}")
    return passed, output


# ─── Stage 5: LLM sim-log analysis (on failure only) ─────────────────────────

SIM_ANALYSIS_SYSTEM = textwrap.dedent("""\
    You are an RTL debug expert. A Verilog simulation has failed.
    Given the simulation log and the original spec, identify:
    1. Which specific test(s) failed
    2. What the root cause likely is in the RTL
    3. What exact fix is needed

    Output format — return a JSON object:
    {
      "failed_tests": ["..."],
      "root_causes": ["..."],
      "fix_hints": ["..."],
      "priority": "high|medium|low"
    }
    Return ONLY valid JSON.
""")


def stage_sim_analysis(sim_log: str, spec_path: pathlib.Path) -> dict:
    """Ask Claude to diagnose the simulation failure."""
    print("[verify] Stage 5 — LLM sim-log analysis ...")
    spec = spec_path.read_text()

    raw = _llm(
        system=SIM_ANALYSIS_SYSTEM,
        user=f"SIMULATION LOG:\n{sim_log}\n\nSPECIFICATION:\n{spec}",
        max_tokens=1024,
    )

    if "```" in raw:
        raw = raw.split("```", 1)[1]
        if raw.lower().startswith("json"):
            raw = raw.split("\n", 1)[1]
        raw = raw.rsplit("```", 1)[0].strip()

    try:
        analysis = json.loads(raw)
    except json.JSONDecodeError:
        analysis = {"failed_tests": [], "root_causes": [raw[:300]], "fix_hints": [], "priority": "high"}

    (LOG_DIR / "sim_analysis.json").write_text(json.dumps(analysis, indent=2))

    for hint in analysis.get("fix_hints", [])[:3]:
        print(f"[verify]   Hint: {hint}")

    return analysis


# ─── Orchestrate all stages ───────────────────────────────────────────────────

def run() -> dict:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    RTL_DIR.mkdir(parents=True, exist_ok=True)

    result = {
        "syntax_ok":    False,
        "spec_ok":      None,
        "synth_ok":     None,
        "sim_ok":       None,
        "errors":       [],
        "spec_issues":  [],
        "fix_hints":    [],
    }

    # ── Guard ────────────────────────────────────────────────────────────────
    if not RTL_FILE.exists():
        msg = "RTL file not found — run code_agent.py first"
        print(f"[verify] ERROR: {msg}")
        result["errors"].append(msg)
        RESULT_FILE.write_text(json.dumps(result, indent=2))
        return result

    # ── Stage 1: Syntax ──────────────────────────────────────────────────────
    syntax_ok, syntax_log = stage_syntax(RTL_FILE)
    result["syntax_ok"] = syntax_ok
    if not syntax_ok:
        result["errors"].append(syntax_log)
        RESULT_FILE.write_text(json.dumps(result, indent=2))
        return result  # no point continuing past a syntax error

    # ── Stage 2: Spec review ─────────────────────────────────────────────────
    spec_ok, issues, summary = stage_spec_review(RTL_FILE, SPEC_PATH)
    result["spec_ok"]     = spec_ok
    result["spec_issues"] = issues
    error_issues = [i["description"] for i in issues if i.get("severity") == "error"]
    if error_issues:
        result["errors"].extend(error_issues)

    # ── Stage 3: Yosys ───────────────────────────────────────────────────────
    synth_ok, synth_log = stage_yosys(RTL_FILE)
    result["synth_ok"] = synth_ok
    if not synth_ok:
        result["errors"].append(f"Yosys synthesis failed:\n{synth_log[:500]}")

    # ── Stage 4: Testbench + simulation ──────────────────────────────────────
    tb_file = _TB_COMMITTED if _TB_COMMITTED.exists() else (
              _TB_GENERATED  if _TB_GENERATED.exists()  else None)

    if tb_file is None:
        # Auto-generate a testbench
        tb_file = stage_gen_testbench(RTL_FILE, SPEC_PATH)

    sim_ok, sim_log = stage_simulate(RTL_FILE, tb_file)
    result["sim_ok"] = sim_ok

    # ── Stage 5: Diagnose sim failure ─────────────────────────────────────────
    if not sim_ok:
        analysis = stage_sim_analysis(sim_log, SPEC_PATH)
        result["fix_hints"]  = analysis.get("fix_hints", [])
        result["errors"].extend(analysis.get("root_causes", []))

    # ── Final verdict ─────────────────────────────────────────────────────────
    overall = syntax_ok and spec_ok and synth_ok and sim_ok
    print(f"\n[verify] ── Overall: {'PASSED' if overall else 'FAILED'} ──")
    print(f"          syntax={syntax_ok}  spec={spec_ok}  synth={synth_ok}  sim={sim_ok}")

    RESULT_FILE.write_text(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    run()
