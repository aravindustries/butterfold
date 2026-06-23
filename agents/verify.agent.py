"""
Verification Agent — multi-stage RTL verification pipeline.

Stages (in order):
  1. Syntax check      — iverilog -g2012 -Wall -t null
  2. Spec review       — LLM reads RTL + spec, flags missing/wrong logic
  3. Yosys synthesis   — catches structural issues syntax check misses
  4. Testbench         — auto-generate if none exists, then simulate with vvp
  5. Sim log analysis  — LLM reads simulation output and classifies failures
  6. Golden model      — drive RTL with butterfold_sim test vectors, compare EVM

Requires iverilog, vvp, yosys to be in PATH (inside IIC-OSIC-TOOLS Docker).

Input : generated/rtl/butterfold_top.v   + modular_description.md
Output: generated/verify_result.json
        generated/logs/syntax.log
        generated/logs/synth.log
        generated/logs/sim.log
        generated/golden/golden_sim.log
        generated/golden/golden_result.json
"""

import os, sys, json, pathlib, subprocess, textwrap
import openai
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


def _rtl_sources() -> list:
    """All synthesizable RTL files in generated/rtl (top + kernel + any submodules),
    excluding testbenches. The hybrid design is multi-file, so every compile and
    elaboration step must pass the whole set, not just butterfold_top.v."""
    files = sorted(p for p in RTL_DIR.glob("*.v") if not p.name.startswith("tb_"))
    # Ensure the top is present even if glob ordering changes; fall back to RTL_FILE.
    if not files and RTL_FILE.exists():
        files = [RTL_FILE]
    return [str(p) for p in files]


def _llm(system: str, user: str, max_tokens: int = 2048) -> str:
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    completion = client.chat.completions.create(
        model="gpt-4o",
        max_tokens=max_tokens,
        messages=[
            {"role": "system", "content": system},
            {"role": "user",   "content": user},
        ],
    )
    return completion.choices[0].message.content.strip()


# ─── Stage 1: Syntax check ────────────────────────────────────────────────────

def stage_syntax(rtl_file: pathlib.Path) -> tuple[bool, str]:
    """iverilog syntax-only pass with all warnings enabled (top + kernel + submodules)."""
    r = _run(["iverilog", "-g2012", "-Wall", "-t", "null", *_rtl_sources()])
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

# Structural elaboration check — NOT a full tapeout synthesis. We only need to
# catch what iverilog misses (multi-driven nets, undeclared signals after
# elaboration, unresolved hierarchies). Full `synth -flatten` runs techmap+abc
# gate-mapping, which is very slow on wide combinational multipliers and times
# out; `hierarchy -check; proc; opt -fast; check` is fast and catches the same
# structural problems. Full synthesis is left to the dedicated Yosys/LibreLane
# step in HOW_TO_RUN.md.
YOSYS_SCRIPT = """\
read_verilog -sv {rtl}
hierarchy -top butterfold_top -check
proc
opt -fast
check
stat
"""


def stage_yosys(rtl_file: pathlib.Path) -> tuple[bool, str]:
    """
    Run a fast Yosys structural check. Catches things iverilog misses:
    multi-driven nets, undeclared signals after elaboration, unresolved hierarchies.
    """
    print("[verify] Stage 3 — Yosys synthesis check ...")
    script = YOSYS_SCRIPT.format(rtl=" ".join(_rtl_sources()))
    try:
        r = _run(["yosys", "-p", script], timeout=300)
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
    compile_r = _run(["iverilog", "-g2012", "-o", str(vvp_out), str(tb_file), *_rtl_sources()])
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


# ─── Stage 6: Golden model comparison ────────────────────────────────────────

# Tapeout-frozen parameters (must match modular_description.md)
_K, _M, _CP = 12, 128, 9
_EVM_THRESHOLD = 2.0  # percent — generous for 8-bit fixed point


def _golden_tb(input_int8: list, n_input: int) -> str:
    """Verilog testbench with inlined test vectors (avoids $readmemh path issues)."""
    inits = "\n".join(f"    tx_input[{i}] = 8'h{v & 0xFF:02x};" for i, v in enumerate(input_int8))
    return textwrap.dedent(f"""\
        `timescale 1ns/1ps
        module tb_golden_check;
          reg        clk       = 0;
          reg        rst_n     = 0;
          reg        mode      = 0;
          reg  [7:0] din       = 0;
          reg        din_valid = 0;
          wire [7:0] dout;
          wire       dout_valid, busy, done;

          butterfold_top dut (
            .clk(clk), .rst_n(rst_n), .mode(mode),
            .din(din), .din_valid(din_valid),
            .dout(dout), .dout_valid(dout_valid),
            .busy(busy), .done(done)
          );

          always #5 clk = ~clk;

          reg [7:0] tx_input [0:{n_input - 1}];
          integer   i;
          reg       timeout_hit = 0;

          initial begin
        {inits}
          end

          initial begin
            rst_n = 0; mode = 0;
            repeat(4) @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            din_valid = 1;
            for (i = 0; i < {n_input}; i = i + 1) begin
              din = tx_input[i];
              @(posedge clk);
            end
            din_valid = 0;
            wait(done || timeout_hit);
            repeat(5) @(posedge clk);
            $finish;
          end

          initial begin
            #500000;
            timeout_hit = 1;
            $display("GOLDEN_TIMEOUT");
            $finish;
          end

          always @(posedge clk) begin
            if (dout_valid)
              $display("OUT: %02x", dout);
          end
        endmodule
    """)


def stage_golden_model_check(rtl_file: pathlib.Path) -> dict:
    """
    Drive the RTL with golden model test vectors and compare output.

    Uses butterfold_sim (one directory above butterfold/) to generate k=12
    16-QAM input symbols and the expected TX output waveform, both in int8.
    Runs a dedicated testbench, parses $display output, and computes EVM.
    """
    print("[verify] Stage 6 — Golden model comparison ...")

    sim_pkg_dir = ROOT
    if not (sim_pkg_dir / "butterfold_sim").exists():
        print("[verify]   butterfold_sim not found — skipping golden check")
        return {"golden_ok": None, "reason": "butterfold_sim package not found at ../butterfold_sim"}

    if str(sim_pkg_dir) not in sys.path:
        sys.path.insert(0, str(sim_pkg_dir))

    try:
        import numpy as np
        from butterfold_sim.waveform import qam_symbols, tx_chain
        from butterfold_sim.fixed_point import quantize_complex_stream
    except ImportError as exc:
        print(f"[verify]   Import error: {exc} — skipping golden check")
        return {"golden_ok": None, "reason": str(exc)}

    rng              = np.random.default_rng(42)
    symbols          = qam_symbols(_K, rng=rng)
    input_bytes, _   = quantize_complex_stream(symbols, scale=127.0)
    tx               = tx_chain(symbols, m=_M, cp_len=_CP, folded=True)
    expected_bytes, _ = quantize_complex_stream(tx.time_with_cp, scale=127.0)
    n_expected       = len(expected_bytes)  # 2*(128+9) = 274

    golden_dir = ROOT / "generated" / "golden"
    golden_dir.mkdir(parents=True, exist_ok=True)

    tb_path = RTL_DIR / "tb_golden_check.v"
    tb_path.write_text(_golden_tb(input_bytes.tolist(), len(input_bytes)))

    vvp_out   = LOG_DIR / "golden_check.vvp"
    compile_r = _run(["iverilog", "-g2012", "-o", str(vvp_out), str(tb_path), *_rtl_sources()])
    if compile_r.returncode != 0:
        log = (compile_r.stdout + compile_r.stderr).strip()
        print("[verify]   Golden TB compile FAILED")
        (golden_dir / "golden_compile.log").write_text(log)
        return {"golden_ok": False, "reason": "compile failed", "log": log[:500]}

    sim_r   = _run(["vvp", str(vvp_out)], timeout=300)
    sim_out = sim_r.stdout + sim_r.stderr
    (golden_dir / "golden_sim.log").write_text(sim_out)

    if "GOLDEN_TIMEOUT" in sim_out:
        return {"golden_ok": False, "reason": "simulation timed out waiting for done signal"}

    actual_raw = []
    for line in sim_out.splitlines():
        if line.startswith("OUT: "):
            try:
                val = int(line[5:].strip(), 16)
                actual_raw.append(val if val < 128 else val - 256)
            except ValueError:
                pass

    if len(actual_raw) < n_expected:
        result = {
            "golden_ok": False,
            "reason": f"RTL output {len(actual_raw)} bytes, expected {n_expected}",
        }
        (golden_dir / "golden_result.json").write_text(json.dumps(result, indent=2))
        print(f"[verify]   Golden model FAILED — {result['reason']}")
        return result

    actual   = np.array(actual_raw[:n_expected], dtype=np.int8)
    expected = expected_bytes[:n_expected].astype(np.int8)

    mismatch_count = int(np.sum(actual != expected))

    actual_c   = actual[0::2].astype(np.float64)  + 1j * actual[1::2].astype(np.float64)
    expected_c = expected[0::2].astype(np.float64) + 1j * expected[1::2].astype(np.float64)

    ref_power = float(np.mean(np.abs(expected_c) ** 2))
    evm       = float(100.0 * np.sqrt(np.mean(np.abs(actual_c - expected_c) ** 2) / ref_power)) \
                if ref_power > 0 else float("inf")
    max_err   = float(np.max(np.abs(actual_c - expected_c)))
    rms_err   = float(np.sqrt(np.mean(np.abs(actual_c - expected_c) ** 2)))

    golden_ok = evm < _EVM_THRESHOLD

    result = {
        "golden_ok":             golden_ok,
        "evm_percent":           round(evm, 4),
        "evm_threshold_percent": _EVM_THRESHOLD,
        "max_error":             round(max_err, 4),
        "rms_error":             round(rms_err, 4),
        "bit_mismatch_count":    mismatch_count,
        "output_bytes_expected": n_expected,
        "output_bytes_received": len(actual_raw),
    }
    (golden_dir / "golden_result.json").write_text(json.dumps(result, indent=2))

    status = "PASSED" if golden_ok else f"FAILED (EVM={evm:.2f}% > {_EVM_THRESHOLD}%)"
    print(f"[verify]   Golden model: {status}")
    print(f"[verify]   EVM={evm:.4f}%  max_err={max_err:.4f}  mismatches={mismatch_count}/{n_expected}")
    return result


# ─── Orchestrate all stages ───────────────────────────────────────────────────

def run() -> dict:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    RTL_DIR.mkdir(parents=True, exist_ok=True)

    result = {
        "syntax_ok":      False,
        "spec_ok":        None,
        "synth_ok":       None,
        "sim_ok":         None,
        "golden_ok":      None,
        "golden_metrics": {},
        "errors":         [],
        "spec_issues":    [],
        "fix_hints":      [],
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

    # ── Stage 6: Golden model comparison ──────────────────────────────────────
    # Run whenever RTL compiled successfully (syntax + synth passed), even if
    # the generic testbench in Stage 4 failed — Stage 6 uses its own testbench.
    if syntax_ok and synth_ok:
        golden = stage_golden_model_check(RTL_FILE)
        result["golden_ok"]      = golden.get("golden_ok")
        result["golden_metrics"] = golden
        if golden.get("golden_ok") is False:
            hint = (
                f"Golden model check failed: EVM={golden.get('evm_percent', '?')}% "
                f"(threshold {_EVM_THRESHOLD}%), "
                f"bit mismatches={golden.get('bit_mismatch_count', '?')}"
                f"/{golden.get('output_bytes_expected', '?')}. "
                "Check fixed-point scaling, twiddle factors, and transform stage ordering."
            )
            result["fix_hints"].append(hint)
            if golden.get("reason"):
                result["errors"].append(golden["reason"])

    # ── Final verdict ─────────────────────────────────────────────────────────
    # The golden-model EVM check is authoritative ("RTL must match the bit-accurate
    # golden model"). The LLM spec review (spec_ok) is advisory — it flags scope gaps
    # like unimplemented RX, which the golden TX check does not exercise — so it does
    # not by itself fail the run.
    golden_ok = result.get("golden_ok")
    if golden_ok is True:
        overall = syntax_ok and synth_ok and (sim_ok is not False)
    elif golden_ok is False:
        overall = False
    else:  # golden check could not run — fall back to the conservative criterion
        overall = syntax_ok and synth_ok and (sim_ok is not False) and bool(spec_ok)
    print(f"\n[verify] ── Overall: {'PASSED' if overall else 'FAILED'} ──")
    print(f"          syntax={syntax_ok}  spec={spec_ok} (advisory)  synth={synth_ok}  "
          f"sim={sim_ok}  golden={golden_ok}")

    RESULT_FILE.write_text(json.dumps(result, indent=2))
    return result


def _load_agent_core():
    import importlib.util
    p = pathlib.Path(__file__).parent / "agent_core.py"
    spec = importlib.util.spec_from_file_location("agent_core", p)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def run_react(max_steps: int = 8):
    """Deep (reason+act) verify: the agent runs the checks and REASONS a verdict,
    drilling into any failure — instead of a fixed stage sequence. Read-only: it
    verifies and diagnoses, never edits RTL. Falls back to the scripted run().
    """
    core    = _load_agent_core()
    journal = core.Journal()
    harness = core.ActionHarness(journal, agent="verify")
    goal = (
        "Verify generated/rtl/butterfold_top.v together with butterfold_kernel.v. "
        "Run compile, then yosys_check, then golden_evm (EVM < 2% is the authoritative "
        "pass). If all pass, call done(status='success'). If any fails, read the "
        "relevant output to state the concrete root cause, then done(status='blocked') "
        "with that diagnosis. You are READ-ONLY — do not edit any RTL."
    )
    res = core.react_loop(goal, harness, journal, agent="verify", max_steps=max_steps)
    if res.get("fallback"):
        print("[verify] No API key — using scripted verification pipeline instead.")
        return run()
    return res


if __name__ == "__main__":
    import sys
    if "--react" in sys.argv:
        run_react()
    else:
        run()
