#!/usr/bin/env bash
# Fill + KLayout DEF→GDS streamout for native-ring + ACH-shell.
set -euo pipefail
PROTO=/headless/aravindustries-repos/butterfold/butterfold_proto
OUT=$PROTO/physical/results/native_power_ring_ach
cd "$PROTO"
openroad -no_init -exit physical/scripts/native_ach_fill.tcl | tee "$OUT/fill.log"
grep -q FILL_DONE "$OUT/fill.log"
grep -q 'ANTENNA_CHECK 0' "$OUT/fill.log"
test -f "$OUT/filled.def"
export ROUTE_DEF=$OUT/filled.def
export OUTPUT_GDS=$OUT/candidate/butterfold_top.gds
python3 physical/scripts/shrink_stream_gds.py | tee "$OUT/stream.log"
SHA=$(awk '/^GDS_SHA256 /{print $2}' "$OUT/stream.log")
echo "STREAMED_GDS_SHA256 $SHA"
if [[ "$SHA" == "d283d354d9d9e8c84636e47215482bd25e81c509b9253e7649a58c13676a92da" ]]; then
  echo "ERROR: streamed SHA is the native-core GDS, not an ACH-shell GDS" >&2
  exit 1
fi
python3 physical/scripts/audit_gds_ach_terminals.py \
  physical/reports/native_power_ring_ach/evidence/D03_ACH_interface.yaml \
  "$OUTPUT_GDS" \
  --json physical/reports/native_power_ring_ach/evidence/gds_ach_terminals.json \
  | tee "$OUT/gds_terminal_audit.log"
python3 physical/scripts/pad_spacing_audit.py \
  physical/reports/native_power_ring_ach/evidence/D03_ACH.def \
  "$OUTPUT_GDS" \
  --json physical/reports/native_power_ring_ach/evidence/pad_spacing.json \
  | tee "$OUT/pad_spacing_audit.log"
echo "STREAM_AUDITS_DONE"
