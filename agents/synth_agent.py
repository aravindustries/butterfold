"""
Synthesis Agent — maps butterfold_top to gates with Yosys and reports area,
cell count, flip-flops, and multipliers.

Unlike verify Stage 3 (a fast structural check), this runs a FULL synthesis.
If the GF180 tapeout standard-cell liberty is found it does real technology
mapping for an area estimate in um^2; otherwise it falls back to generic
synthesis with abstract cell counts.

Input : generated/rtl/butterfold_top.v
Output: generated/synth/butterfold_top_synth.v   (gate-level netlist)
        generated/synth/synth_report.json
        generated/logs/synth_full.log

Run standalone:
    python agents/synth_agent.py
"""
import os, sys, re, json, glob, pathlib, subprocess

ROOT      = pathlib.Path(__file__).parent.parent
RTL_DIR   = ROOT / "generated" / "rtl"
RTL_FILE  = RTL_DIR / "butterfold_top.v"
SYNTH_DIR = ROOT / "generated" / "synth"
LOG_DIR   = ROOT / "generated" / "logs"
TOP       = "butterfold_top"


def _rtl_sources() -> str:
    """Space-joined list of the authored module files only. Uses the known module
    set from the spec so stale files (old kernels, tb_*) lingering in the
    gitignored generated/rtl are never swept into synthesis."""
    import importlib.util
    ms_path = ROOT / "agents" / "module_spec.py"
    spec = importlib.util.spec_from_file_location("module_spec", ms_path)
    ms = importlib.util.module_from_spec(spec); spec.loader.exec_module(ms)
    names = ms.parse()["modules"].keys()
    files = [RTL_DIR / f"{n}.v" for n in names if (RTL_DIR / f"{n}.v").exists()]
    if not files and RTL_FILE.exists():
        files = [RTL_FILE]
    return " ".join(str(p) for p in sorted(files))

# Where GF180 standard-cell liberty files commonly live in IIC-OSIC-TOOLS.
_LIBERTY_GLOBS = [
    "{pdk}/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib",
    "{pdk}/gf180mcu*/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/*tt_025C_5v00.lib",
    "{pdk}/gf180mcu*/libs.ref/*/lib/*tt_*.lib",
    "/foss/pdks/**/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib",
]


def _find_gf180_liberty():
    pdk = os.environ.get("PDK_ROOT", "/foss/pdks")
    for pat in _LIBERTY_GLOBS:
        hits = glob.glob(pat.format(pdk=pdk), recursive=True)
        if hits:
            return sorted(hits)[0]
    return None


def _run(cmd, timeout=600):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def _parse_stat(log: str) -> dict:
    """Extract area / cell / FF / multiplier counts from yosys `stat` output."""
    out = {}
    m = re.search(r"Chip area for (?:module|top module) '[^']+':\s*([0-9.]+)", log)
    if m:
        out["chip_area_um2"] = round(float(m.group(1)), 2)
    m = re.search(r"Number of cells:\s*(\d+)", log)
    if m:
        out["num_cells"] = int(m.group(1))
    # Flip-flops: count any cell whose type contains 'dff' / '_DFF'
    ff = 0
    for cell, n in re.findall(r"^\s+(\S+)\s+(\d+)\s*$", log, flags=re.MULTILINE):
        if re.search(r"(?i)dff|dlatch|sdff", cell):
            ff += int(n)
    if ff:
        out["flip_flops"] = ff
    # Multipliers / DSP-ish cells before techmap (generic synth)
    mul = sum(int(n) for c, n in re.findall(r"^\s+(\$\w*mul\w*)\s+(\d+)\s*$",
                                            log, flags=re.MULTILINE))
    if mul:
        out["multipliers"] = mul
    return out


def run() -> dict:
    SYNTH_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    result = {"synth_ran": False, "tech_mapped": False, "metrics": {}, "liberty": None}

    if not RTL_FILE.exists():
        print("[synth] RTL not found — run code_agent first")
        result["error"] = "rtl missing"
        return result

    liberty = _find_gf180_liberty()
    netlist = SYNTH_DIR / "butterfold_top_synth.v"

    if liberty:
        print(f"[synth] GF180 liberty found — real area estimate")
        print(f"[synth]   {liberty}")
        script = (
            f"read_verilog -sv {_rtl_sources()}\n"
            f"synth -top {TOP} -flatten\n"
            f"dfflibmap -liberty {liberty}\n"
            f"abc -liberty {liberty}\n"
            f"opt_clean\n"
            f"write_verilog -noattr {netlist}\n"
            f"stat -liberty {liberty}\n"
        )
        result["tech_mapped"] = True
        result["liberty"] = liberty
    else:
        print("[synth] GF180 liberty not found — generic synthesis (abstract cell counts)")
        print("[synth]   (set PDK_ROOT or run LibreLane for real area — see librelane/README.md)")
        script = (
            f"read_verilog -sv {_rtl_sources()}\n"
            f"synth -top {TOP} -flatten\n"
            f"write_verilog -noattr {netlist}\n"
            f"stat\n"
        )

    print("[synth] Running Yosys full synthesis (this can take a few minutes)...")
    try:
        r = _run(["yosys", "-p", script], timeout=900)
    except FileNotFoundError:
        print("[synth] Yosys not found — skipping synthesis")
        result["error"] = "yosys not available"
        return result
    except subprocess.TimeoutExpired:
        print("[synth] Yosys timed out (>15 min)")
        result["error"] = "timeout"
        return result

    log = (r.stdout + r.stderr)
    (LOG_DIR / "synth_full.log").write_text(log)

    # A real Yosys error is a line beginning with "ERROR:" — do NOT match the bare
    # substring "ERROR", because legitimate spec port names (iq_alignment_error,
    # cp_error, config_error, error) contain it and would trigger a false failure.
    real_errors = [ln.strip() for ln in log.splitlines()
                   if re.match(r"\s*ERROR:", ln, flags=re.IGNORECASE)]
    if r.returncode != 0 or real_errors:
        print("[synth] Synthesis FAILED — see generated/logs/synth_full.log")
        if real_errors:
            print(f"[synth]   {real_errors[0]}")
        result["error"] = "synth error"
        return result

    metrics = _parse_stat(log)
    result["synth_ran"] = True
    result["metrics"] = metrics
    (SYNTH_DIR / "synth_report.json").write_text(json.dumps(result, indent=2))

    print("[synth] Synthesis OK")
    if "chip_area_um2" in metrics:
        print(f"[synth]   Area        : {metrics['chip_area_um2']} um^2")
    if "num_cells" in metrics:
        print(f"[synth]   Cells       : {metrics['num_cells']}")
    if "flip_flops" in metrics:
        print(f"[synth]   Flip-flops  : {metrics['flip_flops']}")
    if "multipliers" in metrics:
        print(f"[synth]   Multipliers : {metrics['multipliers']} (pre-techmap)")
    print(f"[synth]   Netlist     : {netlist.relative_to(ROOT)}")
    print(f"[synth]   Report      : generated/synth/synth_report.json")
    return result


if __name__ == "__main__":
    run()
