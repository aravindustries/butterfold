#!/bin/bash
# verify_modules.sh — PER-MODULE functional verification for BOTH memory configs.
#
# Flow (identical to the end-to-end check, per module):
#   golden/vectors.py  ->  writes the golden hex vectors (tests/vectors/*.hex)
#                      ->  fed as $readmemh stimulus/expected to each module's
#                          Verilog testbench (tests/modules/tb_<module>.v)
#                      ->  RTL output checked bit-exactly against the golden
#                          (0 mismatches == EVM 0.00% for the complex modules).
#
# The 5 non-memory modules are identical in both configs; only the transform CORE
# differs: rtl/ (register-file) vs rtl_sram/ (SRAM macro + behavioural model).
#
# Run INSIDE the IIC-OSIC-TOOLS container, from the repo root:
#   bash scripts/verify_modules.sh
# Exit status 0 only if every module passes in both configs.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT" || exit 1
B=$(mktemp -d); fail=0

echo "==== golden/vectors.py writes the golden hex vectors ===="
python3 golden/vectors.py 2>&1 | grep -E "vectors" || { echo "ERROR: vector emit failed"; exit 1; }

run_mod () {                 # $1 label   $2 testbench   $3.. rtl sources
  local label="$1" tb="$2"; shift 2
  if ! iverilog -g2012 -o "$B/m.vvp" "$tb" "$@" 2>"$B/e"; then
    printf "  %-26s COMPILE-FAIL: %s\n" "$label" "$(head -1 "$B/e")"; fail=1; return
  fi
  local line; line=$(vvp "$B/m.vvp" 2>&1 | grep -iE "PASS:|FAIL:" | head -1)
  printf "  %-26s %s\n" "$label" "${line:-<no result>}"
  echo "$line" | grep -q "PASS:" || fail=1
}

echo; echo "#### Shared modules (identical RTL in both configs) ####"
run_mod twiddle_source          tests/modules/tb_twiddle_source.v          rtl/twiddle_source.v
run_mod fdiq_io_adapter         tests/modules/tb_fdiq_io_adapter.v         rtl/fdiq_io_adapter.v
run_mod subcarrier_map_extract  tests/modules/tb_subcarrier_map_extract.v  rtl/subcarrier_map_extract.v
run_mod tdiq_io_adapter_cp      tests/modules/tb_tdiq_io_adapter_cp.v      rtl/tdiq_io_adapter_cp.v
run_mod scheduler_addr_control  tests/modules/tb_scheduler_addr_control.v  rtl/scheduler_addr_control.v

echo; echo "#### Transform core — the ONLY module that differs between configs ####"
run_mod "core [register-file]"  tests/modules/tb_unified_mixed_radix_core.v \
        rtl/unified_mixed_radix_core.v
run_mod "core [SRAM macro]"     tests/modules/tb_unified_mixed_radix_core_sram.v \
        rtl_sram/unified_mixed_radix_core.v rtl_sram/sram128x8_behav.v

echo
if [ $fail -eq 0 ]; then
  echo "======================================================================"
  echo "  RESULT: all 6 modules PASS their golden (bit-exact) in BOTH configs."
  echo "  (register-file config = shared 5 + core[rtl];"
  echo "   SRAM config          = shared 5 + core[rtl_sram])"
  echo "======================================================================"
else
  echo "  RESULT: one or more modules FAILED (see above)."
fi
rm -rf "$B"; exit $fail
