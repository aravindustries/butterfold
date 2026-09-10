#!/usr/bin/env bash
# Full LVS on the ACH-shelled native-ring build: magic extract -> unique-name
# fix -> netgen.  Writes only under results/native_power_ring/shell/.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/../.." && pwd)"
export OUT_DIR="$PHYS/results/native_power_ring/shell"
export SHELL_GDS="$OUT_DIR/candidate/butterfold_top.gds"
export SHELL_DEF="$OUT_DIR/filled.def"
export BASE_ENV="$PHYS/results/d03_ach_resized/lvs/extract/_env.tcl"
PDK=/foss/pdks/gf180mcuD
mkdir -p "$OUT_DIR/lvs"
for f in "$SHELL_GDS" "$SHELL_DEF" "$BASE_ENV"; do
  [ -f "$f" ] || { echo "ERROR: missing $f" >&2; exit 1; }
done

echo "=== 1/3 magic device extraction (slow, ~10-20 min)"
# Magic needs the TECH FILE (-T) for layer definitions and the cifinput
# section; the .tcl rcfile alone only loads the device-generator menu.
MAGICRC="$PDK/libs.tech/magic/gf180mcuD.magicrc"
MAGICTECH="$PDK/libs.tech/magic/gf180mcuD.tech"
if [ -f "$MAGICRC" ]; then
  echo "using magicrc: $MAGICRC"
  MAGIC_ARGS=(-noconsole -dnull -rcfile "$MAGICRC")
else
  echo "using tech: $MAGICTECH"
  [ -f "$MAGICTECH" ] || { echo "ERROR: no magicrc and no tech file in $PDK/libs.tech/magic/" >&2; ls "$PDK/libs.tech/magic/" >&2; exit 1; }
  MAGIC_ARGS=(-noconsole -dnull -T "$MAGICTECH" -rcfile "$PDK/libs.tech/magic/gf180mcuD.tcl")
fi
magic "${MAGIC_ARGS[@]}" "$HERE/lvs_shell_extract.tcl" 2>&1 \
    | tee "$OUT_DIR/lvs/magic_extract.log" | tail -6
grep -q "couldn.t be read" "$OUT_DIR/lvs/magic_extract.log" && { echo "ERROR: magic failed to load the design - stopping" >&2; exit 1; } || true
[ -f "$OUT_DIR/lvs/butterfold_top.spice" ] || { echo "ERROR: extraction produced no spice netlist - stopping" >&2; exit 1; }

echo "=== 2/3 unique-name fix"
/foss/tools/openroad/bin/openroad -exit -no_splash -python \
    "$PHYS/scripts/d03_resized_lvs_unique_fix.py" \
    "$OUT_DIR/lvs/butterfold_top.spice" \
    "$OUT_DIR/filled.odb" \
    "$OUT_DIR/lvs/butterfold_top.unique_fixed.spice" \
    2>&1 | tee "$OUT_DIR/lvs/unique_fix.log" | tail -5

echo "=== 3/3 netgen LVS"
export LVS_LAYOUT="$OUT_DIR/lvs/butterfold_top.unique_fixed.spice"
export LVS_SOURCE="$OUT_DIR/butterfold_top.final.pnl.v"
export LVS_REPORT="$OUT_DIR/lvs/lvs.netgen.rpt"
netgen -batch source "$HERE/lvs_shell_netgen.tcl" 2>&1 \
    | tee "$OUT_DIR/lvs/netgen.log" | tail -8
echo "--- result:"
grep -E "Circuits match|Final result|Netlists do not match" "$LVS_REPORT" | tail -3 || echo "(see $LVS_REPORT)"
