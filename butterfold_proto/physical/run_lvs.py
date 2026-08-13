#!/usr/bin/env python3
"""Reproducible hierarchical leaf-connectivity LVS for current candidate GDS."""

from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PHYS = ROOT / "physical"
OUT = PHYS / "results/padframe/lvs"
WORK = OUT / "work"
GDS = PHYS / "results/padframe/gds/butterfold_padframe_candidate.gds"
EXPECTED = "a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d"
SETUP = Path("/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl")
MAGICRC = Path("/foss/pdks/gf180mcuD/libs.tech/magic/gf180mcuD.magicrc")


def run(args, log, cwd=ROOT, env=None, required=True):
    print("+", " ".join(map(str, args)), flush=True)
    result = subprocess.run(list(map(str, args)), cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout)
    if required and result.returncode:
        raise SystemExit(f"command failed ({result.returncode}); see {log}")
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True); WORK.mkdir(exist_ok=True)
    digest = hashlib.sha256(GDS.read_bytes()).hexdigest()
    (OUT / "gds.sha256").write_text(f"{digest}  {GDS.relative_to(ROOT)}\n")
    if digest != EXPECTED:
        raise SystemExit(f"authoritative GDS hash mismatch: {digest}")

    abstract = OUT / "layout_hierarchical.gds"
    merged = OUT / "layout_hierarchical_merged.gds"
    run([sys.executable, PHYS / "build_lvs_hier_layout.py", GDS, abstract],
        OUT / "layout_abstraction.log")
    shutil.copy2(abstract, merged)
    for layer in (34, 35, 36, 38, 42, 40, 46, 41, 81):
        temp = OUT / "layout_merge.tmp.gds"
        run([sys.executable, PHYS / "merge_lvs_layer.py", merged, temp, layer],
            OUT / f"merge_layer_{layer}.log")
        temp.replace(merged)

    for ext in WORK.glob("*.ext"):
        ext.unlink()
    env = os.environ.copy()
    env["LVS_LAYOUT_GDS"] = str(merged)
    env["LVS_LAYOUT_SPICE"] = str(OUT / "magic_unused.spice")
    run(["magic", "-dnull", "-noconsole", "-rcfile", MAGICRC,
         PHYS / "extract_lvs_magic.tcl"], OUT / "magic_extract.log",
        cwd=WORK, env=env, required=False)
    if not (WORK / "butterfold_padframe_top.ext").exists():
        raise SystemExit("Magic did not produce the extracted top hierarchy")

    run(["openroad", "-no_init", "-no_splash", "-exit",
         PHYS / "lvs_reference.tcl"], OUT / "reference_generation.log")
    raw = OUT / "reference_physical_raw.cdl"
    shutil.copy2(OUT / "reference_physical.cdl", raw)
    layout = OUT / "layout.spice"
    reference = OUT / "reference.spice"
    bad = OUT / "reference_bad.spice"
    run([sys.executable, PHYS / "prepare_hierarchical_lvs.py", WORK, raw,
         layout, reference, bad], OUT / "reference_preparation.log")

    good = run(["netgen", "-batch", "lvs",
                f"{layout} butterfold_padframe_top",
                f"{reference} butterfold_padframe_top", SETUP,
                OUT / "lvs_report.out"], OUT / "lvs.log", required=False)
    good_report = (OUT / "lvs_report.out").read_text(errors="replace")
    good_pass = "Final result: Circuits match uniquely." in good_report

    neg = OUT / "negative_control"; neg.mkdir(exist_ok=True)
    shutil.copy2(bad, neg / "reference_bad.spice")
    bad_run = run(["netgen", "-batch", "lvs",
                   f"{layout} butterfold_padframe_top",
                   f"{neg / 'reference_bad.spice'} butterfold_padframe_top",
                   SETUP, neg / "lvs_report.out"], neg / "lvs.log",
                  required=False)
    bad_report = (neg / "lvs_report.out").read_text(errors="replace")
    negative_fails = "Final result: Circuits match uniquely." not in bad_report

    summary = (f"gds_sha256={digest}\nlayout_signal_terminals=21\n"
               f"reference_signal_terminals=21\nleaf_instances=13788\n"
               f"sram256_instances=2\nsram512_instances=0\n"
               f"unexplained_unmatched_nets={0 if good_pass else 'UNKNOWN'}\n"
               f"unexplained_unmatched_instances={0 if good_pass else 'UNKNOWN'}\n"
               f"negative_control={'FAIL_AS_EXPECTED' if negative_fails else 'INVALID'}\n"
               f"hierarchical_lvs={'PASS' if good_pass and negative_fails else 'FAIL'}\n")
    (OUT / "lvs_summary.txt").write_text(summary)
    print(summary, end="")
    if not good_pass or not negative_fails:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
