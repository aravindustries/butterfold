#!/usr/bin/env bash
# Post-LibreLane native-ring signoff helpers. Does not modify ODB.
set -euo pipefail
PROTO=/headless/aravindustries-repos/butterfold/butterfold_proto
RUN=$PROTO/physical/librelane/runs/native_pdn_ring
REP=$PROTO/physical/reports/native_power_ring
mkdir -p "$REP/evidence"
echo "RUN=$RUN"
ls "$RUN/final" 2>/dev/null || true
ls -d "$RUN"/[0-9]*-openroad-detailedrouting 2>/dev/null || true
ls -d "$RUN"/[0-9]*-openroad-fillinsertion 2>/dev/null || true
