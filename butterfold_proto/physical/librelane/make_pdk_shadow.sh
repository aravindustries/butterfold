#!/bin/sh
# Build a writable shadow of the GF180 PDK.
#
# Why: /foss/pdks/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/ ships
# no drc_exclude.cells, but the PDK's own config.tcl names that path.  Newer
# LibreLane validates PDK paths while LOADING THE PDK -- before user config is
# applied -- so no config.json override can reach it, and /foss/pdks is
# root-owned.  This mirrors the PDK with symlinks (no real disk used) and adds
# the one missing file as an empty real file.
#
# Empty = exclude nothing, which reproduces the historical behaviour: the file
# never existed here, and older LibreLane silently ignored the dead path.
# See PDK_COLLATERAL_NOTE.md for the mux2_1 question.
#
# Usage:  sh make_pdk_shadow.sh   then   librelane --pdk-root "$PDK_SHADOW" ...
set -e

SRC=${SRC_PDK_ROOT:-/foss/pdks}
PDK=${PDK_NAME:-gf180mcuD}
SCL=${SCL_NAME:-gf180mcu_fd_sc_mcu9t5v0}
SHADOW=${PDK_SHADOW:-$HOME/pdk_shadow}

[ -d "$SRC/$PDK" ] || { echo "source PDK not found: $SRC/$PDK" >&2; exit 1; }

rm -rf "$SHADOW"
mkdir -p "$SHADOW/$PDK/libs.tech/librelane/$SCL"

# Mirror each level with symlinks, carving out only the path we must modify.
mirror_except() {  # <src dir> <dst dir> <name to skip>
  for e in "$1"/*; do
    b=`basename "$e"`
    [ "$b" = "$3" ] || ln -s "$e" "$2/$b"
  done
}
mirror_except "$SRC/$PDK"                        "$SHADOW/$PDK"                        libs.tech
mirror_except "$SRC/$PDK/libs.tech"              "$SHADOW/$PDK/libs.tech"              librelane
mirror_except "$SRC/$PDK/libs.tech/librelane"    "$SHADOW/$PDK/libs.tech/librelane"    "$SCL"
mirror_except "$SRC/$PDK/libs.tech/librelane/$SCL" "$SHADOW/$PDK/libs.tech/librelane/$SCL" ""

: > "$SHADOW/$PDK/libs.tech/librelane/$SCL/drc_exclude.cells"

echo "shadow PDK ready: $SHADOW"
ls -la "$SHADOW/$PDK/libs.tech/librelane/$SCL/"
