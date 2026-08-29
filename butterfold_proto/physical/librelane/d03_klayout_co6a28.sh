#!/usr/bin/env bash
# Same-GDS KLayout on Mag eco28 SHA ee7eda7f. Proven method from d03_klayout_pgfix.sh.
set -euo pipefail
PDK=/foss/pdks/gf180mcuD
RUNNER=$PDK/libs.tech/klayout/tech/drc/run_drc.py
GDS=/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a28_gds/butterfold_top.magic.gds
BASE=/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate
DRC=$BASE/klayout_drc_co6a28
DEN=$BASE/klayout_density_co6a28
ANT=$BASE/klayout_antenna_co6a28
MSL=$BASE/klayout_mslot_co6a28
mkdir -p "$DRC" "$DEN" "$ANT" "$MSL"

echo "GDS $(sha256sum "$GDS")"
echo "==== MAIN DRC mp=4 ===="
python3 "$RUNNER" \
  --path="$GDS" --variant=D --topcell=butterfold_top --run_mode=flat \
  --mp=4 --thr=2 --run_dir="$DRC" \
  > "$DRC/run_drc.log" 2>&1 || true

solo() {
  local table=$1
  local lyrdb="$DRC/butterfold_top_${table}.lyrdb"
  if [[ -s "$lyrdb" ]]; then
    echo "solo skip $table (lyrdb exists $(wc -c < "$lyrdb") bytes)"
    return 0
  fi
  echo "==== SOLO $table ===="
  python3 "$RUNNER" \
    --path="$GDS" --variant=D --topcell=butterfold_top --run_mode=flat \
    --table="$table" --thr=2 --run_dir="$DRC" \
    > "$DRC/${table}_solo.log" 2>&1 || true
}

solo contact
solo ldpmos
solo nat

echo "==== DENSITY ===="
python3 "$RUNNER" \
  --path="$GDS" --variant=D --topcell=butterfold_top --run_mode=flat \
  --density_only --table=density --thr=4 --run_dir="$DEN" \
  > "$DEN/density.log" 2>&1 || true

echo "==== ANTENNA ===="
python3 "$RUNNER" \
  --path="$GDS" --variant=D --topcell=butterfold_top --run_mode=flat \
  --antenna_only --thr=4 --run_dir="$ANT" \
  > "$ANT/antenna.log" 2>&1 || true

echo "==== MSLOT unified table_name=main ===="
SRC=/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/klayout_drc_mslot_unified
cp -f "$SRC/mslot_unified.drc" "$MSL/mslot_unified.drc"
cp -f "$SRC/layers_def.drc" "$MSL/layers_def.drc"
(
  cd "$MSL"
  klayout -b -r mslot_unified.drc \
    -rd thr=4 -rd metal_top=11K -rd mim_option=B -rd metal_level=5LM \
    -rd verbose=true -rd feol=true -rd beol=true -rd offgrid=true \
    -rd conn_drc=false -rd density=false -rd split_deep=false -rd slow_via=false \
    -rd topcell=butterfold_top -rd input="$GDS" \
    -rd report="$MSL/butterfold_top_mslot.lyrdb" \
    -rd run_mode=flat -rd table_name=main \
    > "$MSL/mslot.log" 2>&1 || true
)

echo "KLAYOUT_CO6A28_DONE"
sha256sum "$GDS"
