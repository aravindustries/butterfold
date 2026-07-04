#!/bin/bash
# ButterFold PPA — SRAM-MACRO scratch memory (4x gf180mcu_fd_ip_sram__sram128x8m8wm1).
# Logic area (yosys, macros = blackbox) + macro area (LEF) + timing/power (OpenSTA
# using the macro .lib) + schematic. Run INSIDE the container: bash scripts/ppa_sram.sh
set +e
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT" || exit 1
OUT=generated/ppa_sram; mkdir -p "$OUT"

STD=$(ls /foss/pdks/gf180mcu*/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/*tt_025C_5v00.lib 2>/dev/null | head -1)
[ -z "$STD" ] && STD=$(find /foss/pdks -name "gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib" 2>/dev/null | head -1)
SRAM=$(find /foss/pdks -name "gf180mcu_fd_ip_sram__sram128x8m8wm1__tt_025C_5v00.lib" 2>/dev/null | head -1)
echo "STDCELL LIBERTY = $STD"
echo "SRAM    LIBERTY = $SRAM"

# SRAM core + macro blackbox first, then the other 5 modules + top.
RTL="rtl_sram/sram128x8_bb.v rtl_sram/unified_mixed_radix_core.v rtl/twiddle_source.v rtl/subcarrier_map_extract.v rtl/fdiq_io_adapter.v rtl/tdiq_io_adapter_cp.v rtl/scheduler_addr_control.v rtl/butterfold_top.v"

echo; echo "======== YOSYS: synthesis + LOGIC AREA (std cells; macros blackbox) ========"
yosys -q -p "
  read_verilog -sv $RTL;
  hierarchy -check -top butterfold_top;
  synth -top butterfold_top -flatten;
  dfflibmap -liberty $STD; abc -liberty $STD; opt_clean;
  write_verilog -noattr $OUT/netlist.v;
  tee -o $OUT/area.txt stat -liberty $STD;
" 2>"$OUT/yosys.err"
grep -E "Number of cells|Chip area|sequential elements" "$OUT/area.txt"

echo; echo "======== MACRO AREA (from LEF SIZE 431.860 x 268.880 um) ========"
python3 -c "m=431.860*268.880; print('  4x sram128x8 = %.1f um^2 = %.4f mm^2 (add to logic area for TOTAL)'%(4*m,4*m/1e6))"

echo; echo "======== OPENSTA: TIMING + POWER (macro timing from SRAM .lib) ========"
cat > "$OUT/sta.tcl" <<EOF
read_liberty $STD
read_liberty $SRAM
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
echo "(all artifacts under $OUT/)"
