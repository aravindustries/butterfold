#!/bin/bash
# Regenerate ButterFold schematics (run inside the container from repo root):
#   bash scripts/gen_schematics.sh
# Produces, under schematics/:
#   architecture.png / .svg   - hand block diagram of the 6-module chip (graphviz)
#   butterfold_top.svg        - yosys 'show' of the integrated top (register-file core)
#   butterfold_top_sram.svg   - yosys 'show' of the integrated top wired with the SRAM core
#   core_sram.svg             - yosys 'show' of the SRAM core (4 macros + datapath FSM)
set +e
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT" || exit 1
S=schematics

dot -Tpng "$S/architecture.dot" -o "$S/architecture.png"
dot -Tsvg "$S/architecture.dot" -o "$S/architecture.svg"

RTL="rtl/twiddle_source.v rtl/unified_mixed_radix_core.v rtl/subcarrier_map_extract.v rtl/fdiq_io_adapter.v rtl/tdiq_io_adapter_cp.v rtl/scheduler_addr_control.v rtl/butterfold_top.v"
yosys -q -p "read_verilog -sv $RTL; hierarchy -top butterfold_top; proc; show -format svg -prefix $S/butterfold_top -notitle butterfold_top" 2>/dev/null

# Integrated top wired with the SRAM-macro core (swap only unified_mixed_radix_core).
SRAM_RTL="rtl_sram/sram128x8_bb.v rtl_sram/unified_mixed_radix_core.v rtl/twiddle_source.v rtl/subcarrier_map_extract.v rtl/fdiq_io_adapter.v rtl/tdiq_io_adapter_cp.v rtl/scheduler_addr_control.v rtl/butterfold_top.v"
yosys -q -p "read_verilog -sv $SRAM_RTL; hierarchy -top butterfold_top; proc; show -format svg -prefix $S/butterfold_top_sram -notitle butterfold_top" 2>/dev/null

yosys -q -p "read_verilog -sv rtl_sram/sram128x8_bb.v rtl_sram/unified_mixed_radix_core.v; hierarchy -top unified_mixed_radix_core; proc; show -format svg -prefix $S/core_sram -notitle unified_mixed_radix_core" 2>/dev/null

ls -l "$S"/*.svg "$S"/*.png
