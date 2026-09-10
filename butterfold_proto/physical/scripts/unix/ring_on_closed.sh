#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/../.." && pwd)"
export BASE_ODB="$PHYS/results/m2_fix/power_ring.odb"
export CONFLICT_LIST="$PHYS/results/m2_fix/ring_conflict_nets.txt"
export OUT_DIR="${RING_OUT:-$PHYS/results/m2_fix/ring1}"
mkdir -p "$OUT_DIR/candidate"
OR=/foss/tools/openroad/bin/openroad
echo "base: $BASE_ODB"; echo "out : $OUT_DIR"
"$OR" -exit -no_splash "$HERE/ring_on_closed.tcl" 2>&1 | tee "$OUT_DIR/ring.log" \
  | grep -iE "^X_|PSM-|Number of violations|^\[ERROR|pdn"
[ -f "$OUT_DIR/filled.def" ] || { echo "stopped before writing views" >&2; exit 1; }
echo "=== streamout"
ROUTE_DEF="$OUT_DIR/filled.def" OUTPUT_GDS="$OUT_DIR/candidate/butterfold_top.gds" \
  python3 "$PHYS/scripts/shrink_stream_gds.py" 2>&1 | tee "$OUT_DIR/streamout.log" \
  | grep -E "GDS_SHA256|GDS_BBOX_UM"
echo "=== ring shapes in the new DEF"
grep -c "SHAPE RING" "$OUT_DIR/filled.def" || true
echo "=== STA"
for c in max_ss min_ff; do
  STA_ODB="$OUT_DIR/filled.odb" CORNER=$c "$OR" -exit -no_splash "$HERE/native_ring_sta.tcl" 2>&1 \
    | tee "$OUT_DIR/sta_$c.log" | grep -E "SETUP_WNS|HOLD_WNS|worst slack|SETUP_VIO|HOLD_VIO|SLEW"
done
