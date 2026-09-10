#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/../.." && pwd)"
SRC="$PHYS/results/native_power_ring"
OUT="$SRC/diag"; mkdir -p "$OUT"
OR=/foss/tools/openroad/bin/openroad
run () {  # tag  odb
  echo "=================== $1"
  STA_ODB="$2" TAG="$1" OUT_DIR="$OUT" "$OR" -exit -no_splash "$HERE/diag_sta.tcl" 2>&1 \
    | tee "$OUT/diag_$1.log" | grep -E "^DIAG_|worst slack|tns "
}
run BASE  "$SRC/filled.odb"        # arav's, no shell   -- the +5.351 claim
run FIX1  "$SRC/fix1/filled.odb"   # shell, routing preserved -- the -3.358
echo "=================== summary"
grep -hE "CASE_ON_WNS|CASE_ON_VIO|CASE_OFF_WNS|CASE_OFF_VIO|OUTPUT_DELAY" "$OUT"/diag_*.log
