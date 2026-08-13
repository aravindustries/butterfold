#!/bin/bash
# verify_core.sh — golden confirmation for the unified_mixed_radix_core.
#
# Emits the Python golden vectors (golden/vectors.py), then checks BOTH memory
# variants of the transform core against them BIT-EXACTLY. Each testbench loads
# the 128-sample bit-reversed grid, runs the 448 radix-2 IFFT-128 butterfly
# micro-ops (addresses + Q1.7 twiddles from the golden), reads the 128 results
# back, and compares every sample to golden/core_exec (core_out.hex):
#   1. register-file core : rtl/unified_mixed_radix_core.v
#   2. SRAM-macro core    : rtl_sram/unified_mixed_radix_core.v
#                           + rtl_sram/sram128x8_behav.v (functional macro model)
#
# Run INSIDE the IIC-OSIC-TOOLS container, from the repo root:
#   bash scripts/verify_core.sh            # run both checks
#   bash scripts/verify_core.sh --waves    # also dump generated/core_*.vcd
# Exit status is 0 only if BOTH cores pass.
#
# Proof artifacts written:
#   tests/vectors/core_out.hex        golden expected output (from golden/core_exec)
#   tests/vectors/core_rf_out.hex     register-file core RTL output (must be identical)
#   tests/vectors/core_sram_out.hex   SRAM-macro   core RTL output (must be identical)
#   generated/core_rf.vcd, core_sram.vcd   waveforms (only with --waves)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT" || exit 1
BUILD=$(mktemp -d)
fail=0
PLUS=""; [ "${1:-}" = "--waves" ] && { PLUS="+DUMP"; mkdir -p generated; }

echo "==== 1/3  Emit golden vectors (golden/vectors.py) ===="
python3 golden/vectors.py || { echo "ERROR: golden vector emit failed"; exit 1; }

run_case () {           # $1=name  $2=testbench  $3..=rtl sources
  local name="$1"; shift
  local tb="$1";   shift
  echo; echo "==== $name ===="
  if ! iverilog -g2012 -o "$BUILD/$name.vvp" "$tb" "$@" 2>"$BUILD/$name.log"; then
    echo "FAIL: $name did not compile"; cat "$BUILD/$name.log"; fail=1; return
  fi
  local out; out=$(vvp "$BUILD/$name.vvp" $PLUS 2>&1)
  echo "$out" | grep -E "PROOF|out\[|PASS:|FAIL:" || echo "$out" | tail -4
  echo "$out" | grep -q "PASS:" || fail=1
  # extra proof: the captured RTL output file must be byte-identical to the golden
  local rtlhex="tests/vectors/${name%%_core}_out.hex"
  case "$name" in
    register_file_core) rtlhex="tests/vectors/core_rf_out.hex" ;;
    sram_macro_core)    rtlhex="tests/vectors/core_sram_out.hex" ;;
  esac
  if [ -f "$rtlhex" ] && diff <(grep -v '^//' "$rtlhex") \
                              <(grep -v '^//' tests/vectors/core_out.hex) >/dev/null 2>&1; then
    echo "  golden diff: $rtlhex matches tests/vectors/core_out.hex (128/128 values identical)"
  fi
}

echo; echo "==== 2/3  Register-file core ===="
run_case "register_file_core" tests/modules/tb_unified_mixed_radix_core.v \
         rtl/unified_mixed_radix_core.v

echo; echo "==== 3/3  SRAM-macro core ===="
run_case "sram_macro_core" tests/modules/tb_unified_mixed_radix_core_sram.v \
         rtl_sram/unified_mixed_radix_core.v rtl_sram/sram128x8_behav.v

echo
if [ "$fail" -eq 0 ]; then
  echo "======================================================================"
  echo "  RESULT: BOTH cores are BIT-EXACT to the golden IFFT-128 (448 uops)."
  echo "======================================================================"
else
  echo "  RESULT: one or more cores FAILED the golden (see above)."
fi
rm -rf "$BUILD"
exit $fail
