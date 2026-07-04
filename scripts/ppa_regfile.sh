#!/bin/bash
# ButterFold PPA — REGISTER-FILE (flip-flop) scratch memory.
# Area (yosys) + timing/power (OpenSTA) + block schematic (yosys show), GF180MCU.
# Run from anywhere INSIDE the IIC-OSIC-TOOLS container:  bash scripts/ppa_regfile.sh
# Pre-layout estimate (ideal wires); no LibreLane/PnR needed. Fast (~1-2 min).
set +e
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT" || exit 1
OUT=generated/ppa_regfile; mkdir -p "$OUT"

LIB=$(ls /foss/pdks/gf180mcu*/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/*tt_025C_5v00.lib 2>/dev/null | head -1)
[ -z "$LIB" ] && LIB=$(find /foss/pdks -name "gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib" 2>/dev/null | head -1)
echo "STDCELL LIBERTY = $LIB"

RTL="rtl/twiddle_source.v rtl/unified_mixed_radix_core.v rtl/subcarrier_map_extract.v rtl/fdiq_io_adapter.v rtl/tdiq_io_adapter_cp.v rtl/scheduler_addr_control.v rtl/butterfold_top.v"

echo; echo "======== YOSYS: synthesis + AREA ========"
yosys -q -p "
  read_verilog -sv $RTL;
  hierarchy -check -top butterfold_top;
  synth -top butterfold_top -flatten;
  dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
  write_verilog -noattr $OUT/netlist.v;
  tee -o $OUT/area.txt stat -liberty $LIB;
" 2>"$OUT/yosys.err"
grep -E "Number of cells|Chip area|sequential elements" "$OUT/area.txt"

echo; echo "======== OPENSTA: TIMING + POWER (period 50 ns / 20 MHz) ========"
cat > "$OUT/sta.tcl" <<EOF
read_liberty $LIB
read_verilog $OUT/netlist.v
link_design butterfold_top
create_clock -name clk -period 50.0 [get_ports clk_i]
set_input_delay  -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]
report_worst_slack -max
report_worst_slack -min
report_tns
report_power -digits 4
EOF
sta -no_init -exit "$OUT/sta.tcl" 2>"$OUT/sta.err"

echo; echo "======== SCHEMATIC (yosys show) ========"
yosys -q -p "read_verilog -sv $RTL; hierarchy -top butterfold_top; proc; show -format svg -prefix $OUT/schematic -notitle butterfold_top;" 2>"$OUT/show.err"
echo "schematic -> $OUT/schematic.svg   (all artifacts under $OUT/)"
