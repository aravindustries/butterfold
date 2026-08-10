#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-${PDK_ROOT:-/usr/share/pdk}}"
echo "Searching under: $ROOT"
find "$ROOT" -type f \( \
  -name 'gf180mcu_fd_ip_sram__sram128x8m8wm1.v' -o \
  -name 'gf180mcu_fd_ip_sram__sram512x8m8wm1.v' \
\) -print
