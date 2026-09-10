#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/.." && pwd)"
export OUT_DIR="${SHELL_OUT:-$PHYS/results/native_power_ring/shell}"
OR=/foss/tools/openroad/bin/openroad
[ -f "$OUT_DIR/shell_routed.odb" ] || { echo "ERROR: run route_ach_shell.sh first" >&2; exit 1; }

echo "=== 1/2 fill + PSM + views"
"$OR" -exit -no_splash "$HERE/fill_ach_shell.tcl" 2>&1 | tee "$OUT_DIR/fill.log" \
  | grep -iE "^X_|PSM-|error" || true

echo "=== 2/2 KLayout DEF -> GDS streamout"
mkdir -p "$OUT_DIR/candidate"
ROUTE_DEF="$OUT_DIR/filled.def" OUTPUT_GDS="$OUT_DIR/candidate/butterfold_top.gds" \
  python3 "$HERE/shrink_stream_gds.py" 2>&1 | tee "$OUT_DIR/streamout.log" \
  | grep -iE "GDS_|INFO|error" || true
