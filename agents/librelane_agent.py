"""
LibreLane Agent — runs the GF180 RTL->GDS physical-design flow on the generated,
golden-verified RTL and reports the GDS path, area, and DRC/LVS signoff status.

This is the final spec->silicon step. Like synth_agent it is SCRIPTED, not a
reason+act agent: PnR is a long deterministic flow, not a tool-choosing loop.

Gated by BUTTERFOLD_GDS=1 because a full GDS run takes many minutes and writes
large artifacts; the orchestrator skips it by default so quick runs stay fast.

Input : generated/rtl/butterfold_top.v + butterfold_kernel.v, librelane/config.yaml
Output: librelane/runs/<timestamp>/final/{gds,metrics.json}; returns a result dict.

Run standalone:
    BUTTERFOLD_GDS=1 python agents/librelane_agent.py
"""
import os, json, glob, pathlib, subprocess

ROOT    = pathlib.Path(__file__).parent.parent
LL_DIR  = ROOT / "librelane"
CONFIG  = LL_DIR / "config.yaml"
RTL_TOP = ROOT / "generated" / "rtl" / "butterfold_top.v"

# Keys of interest in LibreLane's final/metrics.json (best-effort; names vary by
# version, so we also scan generically for drc/lvs below).
_METRIC_KEYS = [
    "design__core__area", "design__die__area", "design__instance__count",
    "power__total", "timing__setup__ws", "clock__skew__worst",
]


def _latest_run() -> pathlib.Path | None:
    runs = sorted(glob.glob(str(LL_DIR / "runs" / "*")))
    return pathlib.Path(runs[-1]) if runs else None


def _signoff_from_metrics(m: dict) -> dict:
    """Pull DRC/LVS signoff counts from a metrics dict under any plausible key."""
    drc = lvs = None
    for k, v in m.items():
        kl = k.lower()
        if drc is None and "drc" in kl and ("count" in kl or "violation" in kl):
            drc = v
        if lvs is None and "lvs" in kl and ("error" in kl or "count" in kl or "violation" in kl):
            lvs = v
    return {"drc_violations": drc, "lvs_errors": lvs}


def parse_run(run_dir: pathlib.Path) -> dict:
    """Extract GDS path, area metrics, and DRC/LVS signoff from a finished run."""
    final = run_dir / "final"
    gds = final / "gds" / "butterfold_top.gds"
    out = {"run_dir": str(run_dir), "gds_path": None, "metrics": {}}
    if gds.exists():
        out["gds_path"] = str(gds)
    mfile = final / "metrics.json"
    if mfile.exists():
        try:
            m = json.loads(mfile.read_text())
            out["metrics"] = {k: m.get(k) for k in _METRIC_KEYS if k in m}
            out.update(_signoff_from_metrics(m))
        except (json.JSONDecodeError, OSError):
            pass
    return out


def run() -> dict:
    result = {"gds_ran": False, "gds_path": None, "metrics": {}, "skipped": None}

    if not os.environ.get("BUTTERFOLD_GDS"):
        result["skipped"] = "set BUTTERFOLD_GDS=1 to run the (long) LibreLane GDS flow"
        print(f"[librelane] Skipped — {result['skipped']}")
        return result

    if not RTL_TOP.exists():
        result["error"] = "RTL not found — run code_agent first"
        print(f"[librelane] {result['error']}")
        return result

    print("[librelane] Running GF180 RTL->GDS (LibreLane) — this takes several minutes...")
    try:
        r = subprocess.run(["librelane", "config.yaml"], cwd=str(LL_DIR),
                           capture_output=True, text=True, timeout=5400)
    except FileNotFoundError:
        result["error"] = "librelane not found (run inside the IIC-OSIC-TOOLS container)"
        print(f"[librelane] {result['error']}")
        return result
    except subprocess.TimeoutExpired:
        result["error"] = "librelane timed out (>90 min)"
        print(f"[librelane] {result['error']}")
        return result

    log = (r.stdout + r.stderr)
    (ROOT / "generated" / "logs").mkdir(parents=True, exist_ok=True)
    (ROOT / "generated" / "logs" / "librelane.log").write_text(log[-20000:], encoding="utf-8")

    run_dir = _latest_run()
    if run_dir is None:
        result["error"] = "no runs/ directory produced"
        print(f"[librelane] {result['error']} (rc={r.returncode})")
        return result

    parsed = parse_run(run_dir)
    result.update(parsed)
    result["gds_ran"] = parsed.get("gds_path") is not None
    result["returncode"] = r.returncode

    (ROOT / "generated" / "gds_result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")

    if result["gds_ran"]:
        m = result.get("metrics", {})
        print(f"[librelane] GDS produced: {result['gds_path']}")
        if m.get("design__die__area") is not None:
            print(f"[librelane]   die area : {m['design__die__area']}")
        if m.get("design__instance__count") is not None:
            print(f"[librelane]   cells    : {m['design__instance__count']}")
        print(f"[librelane]   DRC      : {result.get('drc_violations')}")
        print(f"[librelane]   LVS      : {result.get('lvs_errors')}")
    else:
        print(f"[librelane] Flow finished without a GDS (rc={r.returncode}) — see "
              f"generated/logs/librelane.log")
    return result


if __name__ == "__main__":
    run()
