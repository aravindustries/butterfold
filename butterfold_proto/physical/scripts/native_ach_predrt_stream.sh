#!/usr/bin/env bash
# Fill + KLayout DEF→GDS streamout for the pre-DRT timing-repair candidate.
# Writes ONLY under predrt/. Never overwrites the 80ef23f6 checkpoint GDS.
set -euo pipefail
PROTO=/headless/aravindustries-repos/butterfold/butterfold_proto
OUT=$PROTO/physical/results/native_power_ring_ach/predrt
cd "$PROTO"
openroad -no_init -exit physical/scripts/native_ach_predrt_fill.tcl | tee "$OUT/fill.log"
grep -q FILL_DONE "$OUT/fill.log"
test -f "$OUT/filled.def"
export ROUTE_DEF=$OUT/filled.def
export OUTPUT_GDS=$OUT/candidate/butterfold_top.gds
python3 physical/scripts/shrink_stream_gds.py | tee "$OUT/stream.log"
SHA=$(awk '/^GDS_SHA256 /{print $2}' "$OUT/stream.log")
echo "STREAMED_GDS_SHA256 $SHA"
if [[ "$SHA" == "80ef23f6a45332bc2434a4640072c92b3d6f93d803ee4f5aa02f24d63e0687ad" ]]; then
  echo "ERROR: streamed SHA is the pre-timing checkpoint GDS" >&2
  exit 1
fi
if [[ "$SHA" == "d283d354d9d9e8c84636e47215482bd25e81c509b9253e7649a58c13676a92da" ]]; then
  echo "ERROR: streamed SHA is the native-core GDS, not an ACH-shell GDS" >&2
  exit 1
fi
python3 physical/scripts/audit_gds_ach_terminals.py \
  physical/reports/native_power_ring_ach/evidence/D03_ACH_interface.yaml \
  "$OUTPUT_GDS" \
  --json "$OUT/gds_ach_terminals.json" \
  | tee "$OUT/gds_terminal_audit.log"
python3 physical/scripts/pad_spacing_audit.py \
  physical/reports/native_power_ring_ach/evidence/D03_ACH.def \
  "$OUTPUT_GDS" \
  --json "$OUT/pad_spacing.json" \
  | tee "$OUT/pad_spacing_audit.log"
echo "STREAM_AUDITS_DONE"
