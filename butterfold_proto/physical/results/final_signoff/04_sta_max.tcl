set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
file mkdir $out/sta_max_ss
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/butterfold_top_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/butterfold_top.max.spef

set n 0
foreach p [find_timing_paths -unique_paths_to_endpoint -path_delay max -sort_by_slack -group_path_count 999999999 -slack_max 0] {
  if {[get_property $p slack] < 0} { incr n }
}
puts "SETUP_COUNT $n"
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"
report_worst_slack -max -digits 6
report_tns -max -digits 6
report_worst_slack -min -digits 6
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 > $out/sta_max_ss/electrical_violators.rpt
report_checks -path_delay max -sort_by_slack -group_path_count 1 -endpoint_path_count 1 -digits 6 > $out/sta_max_ss/setup.rpt
report_net rst_n > $out/sta_max_ss/reset_net.rpt
report_net clk > $out/sta_max_ss/clk_net.rpt
report_power -digits 6 > $out/power_vectorless_max_ss.rpt

puts "UNSET_CASE_FOR_RESET_ELEC"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators -digits 4 > $out/sta_max_ss/electrical_reset_visible.rpt
set_case_analysis 1 [get_ports rst_n]
puts "STA_MAX_DONE"
