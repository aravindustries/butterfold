#!/bin/bash
# verify_top.sh — END-TO-END functional confirmation for BOTH integrated tops:
#   * register-file scratch memory   (gen_top.py         -> butterfold_top.v)
#   * SRAM-macro scratch memory      (gen_top_sram.py    -> butterfold_top_sram.v
#                                      + rtl_sram/sram128x8_behav.v)
# Both are self-contained transceivers driven through the spec byte protocol and
# scored with the golden EVM checker (authoritative gate: EVM <= 2.0%):
#   TX (cmd 0x03): 24 in  -> DFT-12 -> map -> IFFT-128 -> CP        -> 274 out
#   RX (cmd 0x04): 274 in -> CP-rm  -> FFT-128 -> extract -> IDFT-12 -> 24 out
#   loopback     : TX out fed back through RX, compared to the original 24 in
#
# Run INSIDE the IIC-OSIC-TOOLS container, from the repo root:
#   bash scripts/verify_top.sh            # run both variants
#   bash scripts/verify_top.sh --waves    # also dump generated/top_{tx,rx}_{rf,sram}.vcd
# Exit status is 0 only if BOTH variants pass TX, RX and loopback.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT" || exit 1
fail=0
PLUS=""; [ "${1:-}" = "--waves" ] && { PLUS="+DUMP"; mkdir -p generated; }

echo "==== Emit golden vectors (golden/vectors.py) ===="
python3 golden/vectors.py >/dev/null || { echo "ERROR: vector emit failed"; exit 1; }
score () { python3 golden/evm_check.py "$1" "$2" 2>&1 | sed -E 's/^\[evm\] //' | tail -1; }

run_variant () {          # $1 label  $2 generator  $3 topfile  $4 tag  $5.. extra srcs
  local label="$1" gen="$2" top="$3" tag="$4"; shift 4
  echo; echo "################  $label  ################"
  python3 "$gen" >/dev/null || { echo "ERROR: $gen failed"; fail=1; return; }

  iverilog -g2012 -o /tmp/${tag}_tx.vvp tests/tb_top_golden.v "$top" "$@" 2>&1 \
    && vvp /tmp/${tag}_tx.vvp $PLUS >/dev/null 2>&1
  [ -n "$PLUS" ] && [ -f generated/top_tx.vcd ] && mv -f generated/top_tx.vcd generated/top_tx_${tag}.vcd
  local tx; tx=$(score generated/rtl/top_out.hex tests/vectors/top_gold.hex)
  echo "  TX    $tx"; echo "$tx" | grep -q PASS || fail=1

  iverilog -g2012 -o /tmp/${tag}_rx.vvp tests/tb_top_rx.v "$top" "$@" 2>&1 \
    && vvp /tmp/${tag}_rx.vvp $PLUS >/dev/null 2>&1
  [ -n "$PLUS" ] && [ -f generated/top_rx.vcd ] && mv -f generated/top_rx.vcd generated/top_rx_${tag}.vcd
  local rx; rx=$(score generated/rtl/rx_out.hex tests/vectors/rx_gold.hex)
  echo "  RX    $rx"; echo "$rx" | grep -q PASS || fail=1

  local lb; lb=$(score generated/rtl/rx_out.hex tests/vectors/top_in.hex)
  echo "  LOOP  $lb"; echo "$lb" | grep -q PASS || fail=1
}

run_variant "Register-file scratch  (gen_top.py)"      gen_top.py \
            generated/rtl/butterfold_top.v      rf
run_variant "SRAM-macro scratch      (gen_top_sram.py)" gen_top_sram.py \
            generated/rtl/butterfold_top_sram.v sram  rtl_sram/sram128x8_behav.v

echo
if [ "$fail" -eq 0 ]; then
  echo "======================================================================"
  echo "  RESULT: BOTH end-to-end tops (register-file + SRAM) PASS"
  echo "          TX + RX + loopback  (EVM gate <= 2.0%)."
  echo "======================================================================"
else
  echo "  RESULT: one or more end-to-end checks FAILED (see above)."
fi
exit $fail
