#!/usr/bin/env bash
# Build a writable shadow of the GF180 PDK at /headless/pdk_shadow.
#
# LibreLane validates PNR_EXCLUDED_CELL_FILE (drc_exclude.cells) while LOADING
# the PDK -- before user config is read -- and the 9-track library ships
# without that file.  /foss/pdks is root-owned and we have no sudo, so mirror
# the PDK with symlinks and add the one missing file.
#
#   usage: ./make_pdk_shadow.sh            (idempotent)
set -euo pipefail

SRC=/foss/pdks/gf180mcuD
DST=/headless/pdk_shadow/gf180mcuD
SCL=gf180mcu_fd_sc_mcu9t5v0

[ -d "$SRC" ] || { echo "ERROR: $SRC not found" >&2; exit 1; }

# mirror a directory with symlinks, leaving one child real so we can descend
mirror () {          # mirror <srcdir> <dstdir> [keep-real-child]
  mkdir -p "$2"
  local e
  for e in "$1"/*; do
    [ -e "$e" ] || continue
    local n; n="$(basename "$e")"
    [ -n "${3:-}" ] && [ "$n" = "$3" ] && continue
    [ -e "$2/$n" ] || ln -s "$e" "$2/$n"
  done
}

mirror "$SRC"                      "$DST"                      libs.tech
mirror "$SRC/libs.tech"            "$DST/libs.tech"            openlane
mirror "$SRC/libs.tech/openlane"   "$DST/libs.tech/openlane"   "$SCL"
mirror "$SRC/libs.tech/openlane/$SCL" "$DST/libs.tech/openlane/$SCL"

for f in drc_exclude.cells no_synth.cells; do
  [ -e "$DST/libs.tech/openlane/$SCL/$f" ] || : > "$DST/libs.tech/openlane/$SCL/$f"
done

echo "shadow PDK ready: /headless/pdk_shadow  (PDK=gf180mcuD, SCL=$SCL)"
ls -l "$DST/libs.tech/openlane/$SCL/" | head
