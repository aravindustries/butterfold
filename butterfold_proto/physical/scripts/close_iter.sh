#!/usr/bin/env bash
# One full closure iteration: extract -> repair setup+hold -> clear+reroute -> STA
#   usage: ./close_iter.sh <tag> <iter-number> [input.odb]
# Input defaults to the previous iteration's routed.odb.
set -euo pipefail
TAG="${1:?usage: close_iter.sh <tag> <n> [input.odb]}"
N="${2:?usage: close_iter.sh <tag> <n> [input.odb]}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/.." && pwd)"
BASE="$PHYS/results/${TAG}_setup_close"
export ITER_DIR="$BASE/iter$N"
PREV="$BASE/iter$((N-1))/route/routed.odb"
[ -f "$PREV" ] || PREV="$BASE/route/routed.odb"
export IN_ODB="${3:-$PREV}"
export OUT_DIR="$ITER_DIR"
export SDC="$PHYS/constraints.sdc"
P=/foss/pdks/gf180mcuD
export RCX_MAX=$P/libs.tech/librelane/rules.openrcx.gf180mcuD.max
export RCX_MIN=$P/libs.tech/librelane/rules.openrcx.gf180mcuD.min
export LIB_STD_SS=$P/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
export LIB_STD_FF=$P/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
export LIB_SRAM_SS=$P/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
export LIB_SRAM_FF=$P/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
OR=/foss/tools/openroad-librelane/bin/openroad
mkdir -p "$ITER_DIR/spef"
echo "iter $N   input: $IN_ODB"

echo "=== 1/4 extract both corners"
IN_ODB="$IN_ODB" OUT_DIR="$ITER_DIR" "$OR" -exit -no_splash "$HERE/reroute_sta.tcl" >/dev/null 2>&1 || true
cat > /tmp/ex_$$.tcl <<T
read_db \$::env(IN_ODB)
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file \$::env(RCX_MAX) -lef_res
write_spef \$::env(ITER_DIR)/spef/butterfold_top.max.spef
extract_parasitics -ext_model_file \$::env(RCX_MIN) -lef_res
write_spef \$::env(ITER_DIR)/spef/butterfold_top.min.spef
puts X_SPEF_OK
T
"$OR" -exit -no_splash /tmp/ex_$$.tcl 2>&1 | tee "$ITER_DIR/extract.log" | grep -E "^X_|RCX-0045"; rm -f /tmp/ex_$$.tcl

echo "=== 2/4 repair setup + hold"
"$OR" -exit -no_splash "$HERE/close_iter.tcl" 2>&1 | tee "$ITER_DIR/repair.log" | grep -E "^X_|worst slack|^tns"

echo "=== 3/4 clear routes, GRT, antenna, DRT"
"$OR" -exit -no_splash "$HERE/reroute_route.tcl" 2>&1 | tee "$ITER_DIR/route.log" | grep -E "^X_|Number of violations"

echo "=== 4/4 re-extract + signoff STA"
cat > /tmp/ex2_$$.tcl <<T
read_db \$::env(ITER_DIR)/route/routed.odb
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file \$::env(RCX_MAX) -lef_res
write_spef \$::env(ITER_DIR)/spef_final/butterfold_top.max.spef
extract_parasitics -ext_model_file \$::env(RCX_MIN) -lef_res
write_spef \$::env(ITER_DIR)/spef_final/butterfold_top.min.spef
T
mkdir -p "$ITER_DIR/spef_final"
"$OR" -exit -no_splash /tmp/ex2_$$.tcl >/dev/null 2>&1; rm -f /tmp/ex2_$$.tcl
OUT_DIR="$ITER_DIR" "$OR" -exit -no_splash "$HERE/reroute_sta2.tcl" 2>&1 | tee "$ITER_DIR/sta.log" | grep -E "^X_|worst slack|^tns"
