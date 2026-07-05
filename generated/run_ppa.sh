#!/bin/bash
# ButterFold PPA: yosys (area) + OpenSTA (timing+power) + yosys show (schematic).
# Runs inside the IIC-OSIC-TOOLS container against /tmp/bf/rtl. Read-only w.r.t.
# the repo; writes only under /tmp/bf.
set +e
cd /tmp/bf || exit 1

echo "==================== ButterFold PPA ===================="
LIB=$(ls /foss/pdks/gf180mcu*/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/*tt_025C_5v00.lib 2>/dev/null | head -1)
[ -z "$LIB" ] && LIB=$(ls /foss/pdks/gf180mcu*/libs.ref/*/lib/*tt_*25C_5v00.lib 2>/dev/null | head -1)
echo "LIBERTY = $LIB"
if [ -z "$LIB" ]; then echo "ERROR: no GF180 liberty found under /foss/pdks"; fi

RTL="rtl/twiddle_source.v rtl/unified_mixed_radix_core.v rtl/subcarrier_map_extract.v rtl/fdiq_io_adapter.v rtl/tdiq_io_adapter_cp.v rtl/scheduler_addr_control.v rtl/butterfold_top.v"

echo
echo "-------- YOSYS: synthesis + area (GF180 gf180mcu_fd_sc_mcu7t5v0) --------"
yosys -q -p "
  read_verilog -sv $RTL;
  hierarchy -check -top butterfold_top;
  synth -top butterfold_top -flatten;
  dfflibmap -liberty $LIB;
  abc -liberty $LIB;
  opt_clean;
  write_verilog -noattr netlist.v;
  tee -o area.txt stat -liberty $LIB;
" 2>yosys.err
echo "---- yosys elaboration/errors (tail) ----"; tail -n 15 yosys.err
echo "---- AREA / CELL REPORT ----"; cat area.txt 2>/dev/null

echo
echo "-------- OPENSTA: timing + power (pre-layout, ideal wires) --------"
cat > sta.tcl <<'EOF'
set lib [lindex [glob /foss/pdks/gf180mcu*/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/*tt_025C_5v00.lib] 0]
read_liberty $lib
read_verilog netlist.v
link_design butterfold_top
create_clock -name clk -period 50.0 [get_ports clk_i]
set_input_delay  -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]
puts "=== worst SETUP (max) path ==="
report_checks -path_delay max -digits 3
puts "=== worst HOLD (min) path ==="
report_checks -path_delay min -digits 3
puts "=== worst slack / TNS ==="
report_worst_slack -max
report_worst_slack -min
report_tns
puts "=== POWER (default switching activity) ==="
report_power -digits 4
EOF
sta -no_init -exit sta.tcl 2>sta.err
echo "---- sta errors (tail) ----"; tail -n 8 sta.err

echo
echo "-------- YOSYS show: block schematic of the integrated top --------"
yosys -q -p "
  read_verilog -sv $RTL;
  hierarchy -top butterfold_top;
  proc;
  show -format svg -prefix /tmp/bf/schematic_butterfold_top -notitle butterfold_top;
" 2>show.err
ls -l /tmp/bf/schematic_butterfold_top.svg 2>&1 || { echo "schematic failed:"; tail -n 5 show.err; }
echo "==================== DONE ===================="
