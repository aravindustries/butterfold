#!/usr/bin/env bash
# Cheap targeted KLayout after first clean Mag GDS.
set -euo pipefail
PDK=/foss/pdks/gf180mcuD
RUNNER=$PDK/libs.tech/klayout/tech/drc/run_drc.py
GDS=/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/co6a36/gds/butterfold_top.magic.gds
DRC=/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/klayout_drc_co6a36_target
mkdir -p "$DRC"
echo "GDS $(sha256sum "$GDS")"
for table in contact metal2 metal3 metal4 metaltop; do
  echo "==== SOLO $table ===="
  python3 "$RUNNER" \
    --path="$GDS" --variant=D --topcell=butterfold_top --run_mode=flat \
    --table="$table" --thr=4 --run_dir="$DRC" \
    > "$DRC/${table}_solo.log" 2>&1 || true
done
python3 - <<'PY'
import os, glob, xml.etree.ElementTree as ET
drc="/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_candidate/klayout_drc_co6a36_target"
want=("CO.6a","M2.1","M2.2a","M2.3","M3.3","M4.3","M4.2a","MT.1")
counts={k:0 for k in want}
for path in sorted(glob.glob(os.path.join(drc,"*.lyrdb"))):
    try:
        root=ET.parse(path).getroot()
    except Exception as e:
        print("PARSE_FAIL", path, e); continue
    local={}
    for item in root.findall(".//item"):
        cat=(item.findtext("category") or "").strip().strip("'\"")
        local[cat]=local.get(cat,0)+1
        for k in want:
            if cat==k or cat.startswith(k):
                counts[k]+=1
    print("FILE", os.path.basename(path), local)
print("TARGET_COUNTS", counts)
PY
echo "KLAYOUT_TARGET_DONE"
sha256sum "$GDS"
