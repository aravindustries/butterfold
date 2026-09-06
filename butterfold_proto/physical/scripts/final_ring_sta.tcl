# Final-ring OpenRCX + STA on power_ring.odb. Does not write the ODB.
# PHASE=setup|hold
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/m2_fix
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
set lib_ff $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
set lib_sram_ff $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
set odb $out/power_ring.odb
file mkdir $out/spef
file mkdir $proto/physical/reports/m2_fix/final_power_ring/evidence/sta
set phase setup
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "FINAL_RING_STA_PHASE $phase"
puts "FINAL_STA_ODB $odb"

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}

if {$phase eq "setup"} {
  define_corners max_ss_125C_4v50
  read_liberty -corner max_ss_125C_4v50 $lib_ss
  read_liberty -corner max_ss_125C_4v50 $lib_sram_ss
  read_db $odb
  read_sdc $sdc
  set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
  set_propagated_clock [all_clocks]
  pg_connect
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  write_spef $out/spef/power_ring.max.spef
  read_spef -corner max_ss_125C_4v50 $out/spef/power_ring.max.spef
  puts "FINAL_STA_MAX_SPEF $out/spef/power_ring.max.spef"
  puts "SETUP_WNS"
  report_worst_slack -max -digits 6
  puts "SETUP_TNS"
  report_tns -max -digits 6
  puts "SETUP_VIOLATIONS [sta::endpoint_violation_count max]"
  report_checks -path_delay max -digits 6 -group_path_count 10 \
    > $proto/physical/reports/m2_fix/final_power_ring/evidence/sta/setup_power_ring.max.rpt
  puts "FINAL_RING_STA_SETUP_DONE"
  exit 0
}

if {$phase eq "hold"} {
  define_corners min_ff_n40C_5v50
  read_liberty -corner min_ff_n40C_5v50 $lib_ff
  read_liberty -corner min_ff_n40C_5v50 $lib_sram_ff
  read_db $odb
  read_sdc $sdc
  set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
  set_propagated_clock [all_clocks]
  pg_connect
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_min -lef_res
  write_spef $out/spef/power_ring.min.spef
  read_spef -corner min_ff_n40C_5v50 $out/spef/power_ring.min.spef
  puts "FINAL_STA_MIN_SPEF $out/spef/power_ring.min.spef"
  puts "HOLD_WNS"
  report_worst_slack -min -digits 6
  puts "HOLD_TNS"
  report_tns -min -digits 6
  puts "HOLD_VIOLATIONS [sta::endpoint_violation_count min]"
  report_checks -path_delay min -digits 6 -group_path_count 10 \
    > $proto/physical/reports/m2_fix/final_power_ring/evidence/sta/hold_power_ring.min.rpt
  puts "FINAL_RING_STA_HOLD_DONE"
  exit 0
}

puts "unknown PHASE $phase"
exit 1
