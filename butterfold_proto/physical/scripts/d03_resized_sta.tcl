# Extracted STA for resized ACH validation integration.
# VIEW=max_ss|min_ff|elec  (default max_ss)
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
file mkdir $out
file mkdir $out/spef
set pdk /foss/pdks/gf180mcuD
set odb $out/routed.odb
if {[info exists env(ODB)] && $env(ODB) ne ""} { set odb $env(ODB) }
set sdc $proto/physical/constraints.sdc
set view [expr {[info exists env(VIEW)] ? $env(VIEW) : "max_ss"}]
puts "STA_ODB $odb"
puts "STA_VIEW $view"

if {$view eq "max_ss" || $view eq "elec"} {
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
  read_db $odb
  read_sdc $sdc
  set_propagated_clock [all_clocks]
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
  write_spef $out/spef/butterfold_top.max.spef
  report_checks -path_delay max -group_path_count 8 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -format full_clock_expanded \
    -fields {capacitance slew fanout input_pin net} > $out/setup_worst.rpt
  report_wns -max -digits 6
  report_tns -max -digits 6
  puts "SETUP_VIO [sta::endpoint_violation_count max]"
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  if {$view eq "elec"} {
    report_check_types -max_slew -max_cap -violators > $out/elec_violators.rpt
    # reset visible
    catch {unset_case_analysis rst_n}
    report_check_types -max_slew -max_cap -violators > $out/elec_reset_violators.rpt
    puts "RESET_SLEW [sta::max_slew_violation_count] RESET_CAP [sta::max_capacitance_violation_count]"
  }
} elseif {$view eq "min_ff"} {
  set c min_ff_n40C_5v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
  read_db $odb
  read_sdc $sdc
  set_propagated_clock [all_clocks]
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min -lef_res
  write_spef $out/spef/butterfold_top.min.spef
  report_checks -path_delay min -group_path_count 8 -endpoint_path_count 1 \
    -unique_paths_to_endpoint -format full_clock_expanded \
    -fields {capacitance slew fanout input_pin net} > $out/hold_worst.rpt
  report_wns -min -digits 6
  report_tns -min -digits 6
  puts "HOLD_VIO [sta::endpoint_violation_count min]"
}
puts "VIEW_DONE $view"
exit
