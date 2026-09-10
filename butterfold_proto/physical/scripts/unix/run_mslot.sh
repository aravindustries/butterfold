#!/usr/bin/env bash
# MSLOT check using the committed unified deck (the m2_fix copy referenced by
# native_ring_run_drc.sh is not in the repo; this is the same deck from the
# d03_ach_resized signoff).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/../.." && pwd)"
GDS="${1:-$PHYS/results/native_power_ring/shell/candidate/butterfold_top.gds}"
OUT="${2:-$PHYS/results/native_power_ring/shell/klayout_drc}"
DECK="$PHYS/results/d03_ach_resized/klayout_mslot/mslot_unified.drc"
[ -f "$DECK" ] || { echo "ERROR: deck missing: $DECK" >&2; exit 1; }
mkdir -p "$OUT/mslot"
echo "GDS  $GDS"
echo "DECK $DECK"
klayout -b -r "$DECK" \
  -rd input="$GDS" -rd topcell=butterfold_top \
  -rd report="$OUT/mslot/butterfold_top_mslot.lyrdb" \
  -rd thr=8 -rd run_mode=flat -rd table_name=main \
  -rd feol=true -rd beol=true \
  -rd metal_top=11K -rd mim_option=B -rd metal_level=5LM \
  > "$OUT/mslot.log" 2>&1 || { echo "MSLOT_FAIL"; tail -20 "$OUT/mslot.log"; exit 1; }
echo -n "MSLOT items: "
grep -c "<item>" "$OUT/mslot/butterfold_top_mslot.lyrdb" 2>/dev/null || echo "(no lyrdb)"
