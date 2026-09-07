#!/usr/bin/env bash
# Extracted-aware setup closure on a LibreLane run's post-DRT database.
#   usage: ./close_setup.sh <run-tag>        e.g. ./close_setup.sh ring7
set -euo pipefail
TAG="${1:?usage: close_setup.sh <run-tag>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHYS="$(cd "$HERE/.." && pwd)"
RUN="$PHYS/librelane/runs/$TAG"

export IN_ODB="$RUN/46-odb-reportdisconnectedpins/butterfold_top.odb"
[ -f "$IN_ODB" ] || IN_ODB="$(ls "$RUN"/*-odb-reportdisconnectedpins/butterfold_top.odb)"
export OUT_DIR="$PHYS/results/${TAG}_setup_close"
export SDC="$PHYS/constraints.sdc"
export RCX_RULES=/foss/pdks/gf180mcuD/libs.tech/librelane/rules.openrcx.gf180mcuD.max
export LIB_STD=/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
export LIB_SRAM=/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
OPENROAD=/foss/tools/openroad-librelane/bin/openroad

mkdir -p "$OUT_DIR"
echo "input : $IN_ODB"
echo "output: $OUT_DIR"
echo "=== 1/2 extract max-corner SPEF"
"$OPENROAD" -exit -no_splash "$HERE/setup_close_extract.tcl" 2>&1 | tee "$OUT_DIR/extract.log" | tail -3
echo "=== 2/2 repair_design + repair_timing -setup"
"$OPENROAD" -exit -no_splash "$HERE/setup_close_repair.tcl" 2>&1 | tee "$OUT_DIR/repair.log" | grep -E "^X_|worst slack|^tns" || true
