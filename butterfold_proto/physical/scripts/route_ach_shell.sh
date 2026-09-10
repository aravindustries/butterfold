#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/.." && pwd)"
export OUT_DIR="${SHELL_OUT:-$PHYS/results/native_power_ring/shell}"
[ -f "$OUT_DIR/shell_placed.odb" ] || { echo "ERROR: run apply_ach_shell.sh first" >&2; exit 1; }
/foss/tools/openroad/bin/openroad -exit -no_splash "$HERE/route_ach_shell.tcl" \
    2>&1 | tee "$OUT_DIR/route.log" | grep -iE "^X_|Number of violations|error" || true
