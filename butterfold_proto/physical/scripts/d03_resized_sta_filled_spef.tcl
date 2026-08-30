# Cheap extracted STA on the filled candidate using existing SPEF (no re-extract).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
set pdk /foss/pdks/gf180mcuD
set view [expr {[info exists env(VIEW)] ? $env(VIEW) : "max_ss"}]
puts "STA_FILLED_ODB $out/filled.odb VIEW $view"

if {$view eq "max_ss" || $view eq "elec"} {
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
  read_db $out/filled.odb
  read_sdc $proto/physical/constraints.sdc
  set_propagated_clock [all_clocks]
  read_spef -corner $c $out/spef/butterfold_top.max.spef
  report_wns -max -digits 6
  report_tns -max -digits 6
  puts "SETUP_VIO [sta::endpoint_violation_count max]"
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  if {$view eq "elec"} {
    report_check_types -max_slew -max_cap -violators > $out/elec_case_on.rpt
    catch {unset_case_analysis rst_n}
    puts "RESET_SLEW [sta::max_slew_violation_count] RESET_CAP [sta::max_capacitance_violation_count]"
    report_check_types -max_slew -max_cap -violators > $out/elec_reset_visible.rpt
  }
} elseif {$view eq "min_ff"} {
  set c min_ff_n40C_5v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
  read_db $out/filled.odb
  read_sdc $proto/physical/constraints.sdc
  set_propagated_clock [all_clocks]
  read_spef -corner $c $out/spef/butterfold_top.min.spef
  report_wns -min -digits 6
  report_tns -min -digits 6
  puts "HOLD_VIO [sta::endpoint_violation_count min]"
}
puts "VIEW_DONE $view"
exit
