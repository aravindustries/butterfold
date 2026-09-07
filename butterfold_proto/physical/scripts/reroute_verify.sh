#!/usr/bin/env bash
#   usage: ./reroute_verify.sh <run-tag>      e.g. ./reroute_verify.sh ring7
set -euo pipefail
TAG="${1:?usage: reroute_verify.sh <run-tag>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/.." && pwd)"
export OUT_DIR="$PHYS/results/${TAG}_setup_close"
export SDC="$PHYS/constraints.sdc"
P=/foss/pdks/gf180mcuD
export RCX_MAX=$P/libs.tech/librelane/rules.openrcx.gf180mcuD.max
export RCX_MIN=$P/libs.tech/librelane/rules.openrcx.gf180mcuD.min
export LIB_STD_SS=$P/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
export LIB_STD_FF=$P/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
export LIB_SRAM_SS=$P/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
export LIB_SRAM_FF=$P/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
OPENROAD=/foss/tools/openroad-librelane/bin/openroad
[ -f "$OUT_DIR/setup_closed.odb" ] || { echo "ERROR: run close_setup.sh $TAG first" >&2; exit 1; }
echo "=== 1/3 global + detailed route"
"$OPENROAD" -exit -no_splash "$HERE/reroute_route.tcl" 2>&1 | tee "$OUT_DIR/route.log" | grep -E "^X_|Number of violations" || true
echo "=== 2/3 extract"
"$OPENROAD" -exit -no_splash "$HERE/reroute_sta.tcl" 2>&1 | tee "$OUT_DIR/extract2.log" | grep -E "^X_|RCX-0045" || true
echo "=== 3/3 signoff STA"
"$OPENROAD" -exit -no_splash "$HERE/reroute_sta2.tcl" 2>&1 | tee "$OUT_DIR/sta.log" | grep -E "^X_|worst slack|^tns" || true
