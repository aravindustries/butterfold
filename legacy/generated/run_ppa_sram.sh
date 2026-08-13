#!/bin/bash
# ButterFold PPA — SRAM-macro variant. yosys (logic area, macros as blackbox) +
# macro area from LEF + OpenSTA (timing/power with the SRAM macro .lib).
set +e
cd /tmp/bf_sram || exit 1

echo "==================== ButterFold PPA (SRAM macro) ===================="
STD=$(ls /foss/pdks/gf180mcu*/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/*tt_025C_5v00.lib 2>/dev/null | head -1)
SRAM=$(find /foss/pdks -name "gf180mcu_fd_ip_sram__sram128x8m8wm1__tt_025C_5v00.lib" 2>/dev/null | head -1)
echo "STDCELL  = $STD"
echo "SRAM LIB = $SRAM"

RTL="rtl_sram/sram128x8_bb.v rtl_sram/unified_mixed_radix_core.v rtl/twiddle_source.v rtl/subcarrier_map_extract.v rtl/fdiq_io_adapter.v rtl/tdiq_io_adapter_cp.v rtl/scheduler_addr_control.v rtl/butterfold_top.v"

echo
echo "-------- YOSYS: synthesis + logic area (macros = blackbox) --------"
yosys -q -p "
  read_verilog -sv $RTL;
  hierarchy -check -top butterfold_top;
  synth -top butterfold_top -flatten;
  dfflibmap -liberty $STD;
  abc -liberty $STD;
  opt_clean;
  write_verilog -noattr netlist_sram.v;
  tee -o area_sram.txt stat -liberty $STD;
" 2>yosys_sram.err
echo "---- yosys errors (tail) ----"; tail -n 12 yosys_sram.err
echo "---- LOGIC AREA / CELLS (stdcells only; 4 SRAM macros are blackboxes) ----"; cat area_sram.txt 2>/dev/null

echo
echo "-------- MACRO area (from LEF SIZE 431.860 x 268.880 um) --------"
python3 -c "m=431.860*268.880; print('  1x sram128x8    = %.1f um^2'%m); print('  4x (re/im,hi/lo) = %.1f um^2 = %.4f mm^2'%(4*m,4*m/1e6))"

echo
echo "-------- OPENSTA: timing + power (macro timing from SRAM .lib) --------"
cat > sta_sram.tcl <<EOF
read_liberty $STD
read_liberty $SRAM
read_verilog netlist_sram.v
link_design butterfold_top
create_clock -name clk -period 50.0 [get_ports clk_i]
set_input_delay  -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]
puts "=== worst SETUP (max) path ==="
report_checks -path_delay max -digits 3
puts "=== worst slack / TNS ==="
report_worst_slack -max
report_worst_slack -min
report_tns
puts "=== POWER (default switching activity) ==="
report_power -digits 4
EOF
sta -no_init -exit sta_sram.tcl 2>sta_sram.err
echo "---- sta errors (tail) ----"; tail -n 8 sta_sram.err
echo "==================== DONE ===================="
