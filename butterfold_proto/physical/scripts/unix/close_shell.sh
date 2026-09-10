#!/usr/bin/env bash
# One full closure iteration on the ACH-shelled native-ring build:
#   extract -> repair setup+hold -> clear+reroute -> fill+PSM -> stream GDS -> STA
#   usage: ./close_shell.sh <iter-n> [input.odb]     (default input: previous iter, else shell2/filled.odb)
set -euo pipefail
N="${1:?usage: close_shell.sh <iter-n> [input.odb]}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/../.." && pwd)"
BASE="$PHYS/results/native_power_ring"
export ITER_DIR="$BASE/close$N"
PREV="$BASE/close$((N-1))/filled.odb"; [ -f "$PREV" ] || PREV="$BASE/shell2/filled.odb"
export IN_ODB="${2:-$PREV}"
export SDC="$PHYS/constraints.sdc"
P=/foss/pdks/gf180mcuD
export RCX_MAX=$P/libs.tech/librelane/rules.openrcx.gf180mcuD.max
export RCX_MIN=$P/libs.tech/librelane/rules.openrcx.gf180mcuD.min
export LIB_STD_SS=$P/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
export LIB_STD_FF=$P/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
export LIB_SRAM_SS=$P/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
export LIB_SRAM_FF=$P/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
OR=/foss/tools/openroad/bin/openroad
mkdir -p "$ITER_DIR/spef" "$ITER_DIR/candidate"
echo "iter $N   input: $IN_ODB"

echo "=== 1/5 extract both corners"
cat > "$ITER_DIR/_ex.tcl" <<T
read_db \$::env(IN_ODB)
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file \$::env(RCX_MAX) -lef_res
write_spef \$::env(ITER_DIR)/spef/butterfold_top.max.spef
extract_parasitics -ext_model_file \$::env(RCX_MIN) -lef_res
write_spef \$::env(ITER_DIR)/spef/butterfold_top.min.spef
puts X_SPEF_OK
T
"$OR" -exit -no_splash "$ITER_DIR/_ex.tcl" 2>&1 | tee "$ITER_DIR/extract.log" | grep -iE "^X_|RCX-0045"

echo "=== 2/5 repair setup + hold"
"$OR" -exit -no_splash "$HERE/shell_repair.tcl" 2>&1 | tee "$ITER_DIR/repair.log" | grep -iE "^X_|worst slack|^tns"

echo "=== 3/5 clear routes + reroute"
"$OR" -exit -no_splash "$HERE/shell_reroute.tcl" 2>&1 | tee "$ITER_DIR/route.log" | grep -iE "^X_|Number of violations"

echo "=== 4/5 fill + PSM + views"
"$OR" -exit -no_splash "$HERE/shell_fill.tcl" 2>&1 | tee "$ITER_DIR/fill.log" | grep -iE "^X_|PSM-"

echo "=== 5/5 streamout + STA"
ROUTE_DEF="$ITER_DIR/filled.def" OUTPUT_GDS="$ITER_DIR/candidate/butterfold_top.gds" \
  python3 "$PHYS/scripts/shrink_stream_gds.py" 2>&1 | tee "$ITER_DIR/streamout.log" | grep -E "GDS_SHA256|GDS_BBOX_UM"
for c in max_ss min_ff; do
  STA_ODB="$ITER_DIR/filled.odb" CORNER=$c "$OR" -exit -no_splash "$HERE/native_ring_sta.tcl" 2>&1 \
    | tee "$ITER_DIR/sta_$c.log" | grep -E "SETUP_WNS|HOLD_WNS|worst slack|SETUP_VIO|HOLD_VIO|SLEW"
done
