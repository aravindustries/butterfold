# SPEF-aware STA for the native-ring + ACH-shell filled ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set pdk /foss/pdks/gf180mcuD
set odb $out/filled.odb
if {[info exists ::env(STA_ODB)] && $::env(STA_ODB) ne ""} { set odb $::env(STA_ODB) }
set corner max_ss
if {[info exists ::env(CORNER)] && $::env(CORNER) ne ""} { set corner $::env(CORNER) }
puts "STA_ODB $odb"
puts "STA_CORNER $corner"
file mkdir $out/spef

if {$corner eq "max_ss"} {
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
  read_db $odb
  read_sdc $proto/physical/constraints.sdc
  set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
  set_propagated_clock [all_clocks]
  set spef $out/spef/final.max.spef
  if {![file exists $spef]} {
    define_process_corner -ext_model_index 0 CURRENT_CORNER
    extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
    write_spef $spef
  }
  read_spef -corner $c $spef
  puts "SETUP_WNS"
  report_worst_slack -max -digits 6
  puts "SETUP_TNS"
  report_tns -max -digits 6
  if {[catch {puts "SETUP_VIO [sta::endpoint_violation_count max]"} m]} { puts "SETUP_VIO_CAUGHT $m" }
  if {[catch {puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"} m]} {
    puts "SLEW_CAP_CAUGHT $m"
  }
  report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 > $out/electrical_case.rpt
} elseif {$corner eq "min_ff"} {
  set c min_ff_n40C_5v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
  read_db $odb
  read_sdc $proto/physical/constraints.sdc
  set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
  set_propagated_clock [all_clocks]
  set spef $out/spef/final.min.spef
  if {![file exists $spef]} {
    define_process_corner -ext_model_index 0 CURRENT_CORNER
    extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min -lef_res
    write_spef $spef
  }
  read_spef -corner $c $spef
  puts "HOLD_WNS"
  report_worst_slack -min -digits 6
  puts "HOLD_TNS"
  report_tns -min -digits 6
  if {[catch {puts "HOLD_VIO [sta::endpoint_violation_count min]"} m]} { puts "HOLD_VIO_CAUGHT $m" }
} else {
  puts "UNKNOWN_CORNER $corner"
  exit 1
}
puts "STA_DONE"
exit
