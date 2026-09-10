#!/usr/bin/env bash
# Stage 1 of ACH shell application: create terminals + tie cells, legalize.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/.." && pwd)"
SRC="$PHYS/results/native_power_ring"
export OUT_DIR="${SHELL_OUT:-$SRC/shell}"
export SHELL_TCL="$SRC/ach_shell.tcl"
mkdir -p "$OUT_DIR"
# never modify the committed filled.odb
export BASE_ODB="$OUT_DIR/base.odb"
[ -f "$BASE_ODB" ] || cp "$SRC/filled.odb" "$BASE_ODB"
[ -f "$SHELL_TCL" ] || { echo "ERROR: $SHELL_TCL missing - run generate_final_ach_shell.py first" >&2; exit 1; }
/foss/tools/openroad/bin/openroad -exit -no_splash "$HERE/apply_ach_shell.tcl" \
    2>&1 | tee "$OUT_DIR/apply.log" | grep -iE "^X_|ACH_SHELL_|error" || true
