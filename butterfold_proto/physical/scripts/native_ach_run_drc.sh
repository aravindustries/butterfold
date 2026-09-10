#!/usr/bin/env bash
# Authoritative GF180 separate-table non-fill DRC + MSLOT on the ACH-shell GDS.
set -euo pipefail
PROTO=/headless/aravindustries-repos/butterfold/butterfold_proto
GDS=${1:-$PROTO/physical/results/native_power_ring_ach/candidate/butterfold_top.gds}
OUT=${2:-$PROTO/physical/results/native_power_ring_ach/klayout_drc}
RUNNER=/foss/pdks/gf180mcuD/libs.tech/klayout/tech/drc/run_drc.py
TABLES=(metal1 metal2 metal3 metal4 metal5 metaltop via1 via2 via3 via4 poly2 nplus pplus comp contact nwell)
mkdir -p "$OUT"
if [[ ! -f "$GDS" ]]; then
  echo "missing GDS $GDS" >&2
  exit 1
fi
echo "GDS $GDS"
echo "OUT $OUT"
for t in "${TABLES[@]}"; do
  extra=(--no_connectivity)
  if [[ "$t" == "nwell" ]]; then
    extra=()
  fi
  echo "TABLE $t"
  python3 "$RUNNER" \
    --path="$GDS" \
    --variant=D \
    --table="$t" \
    --run_mode=flat \
    --topcell=butterfold_top \
    --thr=4 \
    --run_dir="$OUT/$t" \
    "${extra[@]}" \
    > "$OUT/${t}.log" 2>&1 || {
      echo "TABLE_FAIL $t" >&2
      tail -20 "$OUT/${t}.log" >&2
      exit 1
    }
done
MSLOT_DECK=$PROTO/physical/results/m2_fix/klayout/mslot/mslot_unified.drc
mkdir -p "$OUT/mslot"
klayout -b \
  -r "$MSLOT_DECK" \
  -rd input="$GDS" \
  -rd topcell=butterfold_top \
  -rd report="$OUT/mslot/butterfold_top_mslot.lyrdb" \
  -rd thr=8 \
  -rd run_mode=flat \
  -rd table_name=main \
  -rd feol=true \
  -rd beol=true \
  -rd metal_top=11K \
  -rd mim_option=B \
  -rd metal_level=5LM \
  > "$OUT/mslot.log" 2>&1 || {
    echo "MSLOT_FAIL" >&2
    tail -20 "$OUT/mslot.log" >&2
    exit 1
  }
python3 - <<PY
import glob, os, xml.etree.ElementTree as ET
out = "$OUT"
rows = []
total = 0
for t in """${TABLES[@]}""".split():
    logs = glob.glob(os.path.join(out, t, "*.lyrdb")) + glob.glob(os.path.join(out, t, "*", "*.lyrdb"))
    n = 0
    for f in logs:
        try:
            root = ET.parse(f).getroot()
        except Exception:
            continue
        n += len(root.findall(".//item"))
    rows.append((t, n, logs))
    total += n
mslot = 0
for f in glob.glob(os.path.join(out, "mslot", "*.lyrdb")) + glob.glob(os.path.join(out, "mslot", "*", "*.lyrdb")):
    try:
        root = ET.parse(f).getroot()
    except Exception:
        continue
    mslot += len(root.findall(".//item"))
print("NON_FILL_DRC_TOTAL", total)
for t, n, logs in rows:
    print(f"  {t}: {n} items  {logs[:2]}")
print("MSLOT_TOTAL", mslot)
open(os.path.join(out, "summary.txt"), "w").write(f"NON_FILL_DRC_TOTAL {total}\nMSLOT_TOTAL {mslot}\n")
if total != 0 or mslot != 0:
    raise SystemExit(1)
PY
echo "DRC_MSLOT_PASS"
