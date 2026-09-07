#!/usr/bin/env bash
# Full clean LibreLane run for butterfold_top with the PDN-generated core ring.
#
# The flow cannot run end-to-end in one command: the official ACH Metal2
# VDD/VSS pin shapes must be stitched to the core PDN by
# eco_connect_template_pg.py, on the ODB produced by Odb.ApplyDEFTemplate,
# before placement continues.  This script runs the three phases in order so
# the stitch is never skipped.
#
#   usage:  ./run_full_ring.sh <run-tag>          e.g.  ./run_full_ring.sh ring6
set -euo pipefail

TAG="${1:?usage: run_full_ring.sh <run-tag>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESIGN_ROOT="$(cd "$HERE/../../.." && pwd)"
CONFIG="$HERE/config.json"
RUNDIR="$HERE/runs/$TAG"

# ODBs are written by LibreLane's OpenROAD (schema 0.126); the standalone
# /foss/tools/openroad is newer and refuses to read them.
OPENROAD=/foss/tools/openroad-librelane/bin/openroad

LL=(librelane --manual-pdk --pdk-root /headless/pdk_shadow
    -p gf180mcuD -s gf180mcu_fd_sc_mcu9t5v0
    --run-tag "$TAG" -j 16 "$CONFIG")

export PDK_ROOT=/headless/pdk_shadow PDK=gf180mcuD

[ -d /headless/pdk_shadow ] || { echo "ERROR: /headless/pdk_shadow missing - recreate the shadow PDK first." >&2; exit 1; }
[ -e "$RUNDIR" ] && { echo "ERROR: $RUNDIR already exists - pick an unused run tag." >&2; exit 1; }

cd "$DESIGN_ROOT"

echo "=== phase 1/3: synthesis -> ApplyDEFTemplate"
"${LL[@]}" --to Odb.ApplyDEFTemplate

STEP="$(ls -d "$RUNDIR"/*-odb-applydeftemplate)"
echo "=== phase 2/3: PG stitch ECO in $(basename "$STEP")"
cd "$STEP"
[ -e unstitched.odb ] || cp butterfold_top.odb unstitched.odb
"$OPENROAD" -no_splash -python "$HERE/eco_connect_template_pg.py" \
    unstitched.odb butterfold_top.odb butterfold_top.def

cd "$DESIGN_ROOT"
echo "=== phase 3/3: GlobalPlacement -> signoff"
"${LL[@]}" --from OpenROAD.GlobalPlacement

echo
echo "=== done. results:"
python3 - "$RUNDIR" <<'PY'
import json, sys, os
m = json.load(open(os.path.join(sys.argv[1], "final", "metrics.json")))
for k in ("route__drc_errors", "design__lvs_error__count",
          "design__power_grid_violation__count", "design__xor_difference__count",
          "route__antenna_violation__count", "antenna_diodes_count",
          "design__instance__count__class:antenna_cell",
          "design__instance__utilization", "timing__setup__ws",
          "magic__drc_error__count"):
    print(f"  {k:46s} {m.get(k)}")
PY
