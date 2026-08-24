# Native OpenRCX + multi-corner STA on the filled ODB.
# LibreLane Classic sequences FillInsertion before RCX.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
set odb $out/butterfold_top_filled.odb
file mkdir $out/spef_filled
file mkdir $out/sta_filled_max_ss
file mkdir $out/sta_filled_min_ff

puts "FILLED_RCX_MAX"
read_db $odb
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file /foss/pdks/gf180mcuD/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
write_spef $out/spef_filled/butterfold_top.max.spef
puts WROTE_FILLED_MAX

puts "FILLED_RCX_MIN"
extract_parasitics -ext_model_file /foss/pdks/gf180mcuD/libs.tech/librelane/rules.openrcx.gf180mcuD.min -lef_res
write_spef $out/spef_filled/butterfold_top.min.spef
puts WROTE_FILLED_MIN

puts "FILLED_STA"
set cmax max_ss_125C_4v50
set cmin min_ff_n40C_5v50
define_corners $cmax $cmin
read_liberty -corner $cmax /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $cmax /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_liberty -corner $cmin /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty -corner $cmin /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $cmax $out/spef_filled/butterfold_top.max.spef
read_spef -corner $cmin $out/spef_filled/butterfold_top.min.spef

puts "FILLED_SETUP_SLEW [sta::max_slew_violation_count]"
puts "FILLED_SETUP_CAP [sta::max_capacitance_violation_count]"
report_worst_slack -max -digits 6
report_tns -max -digits 6
report_worst_slack -min -digits 6
report_tns -min -digits 6
report_checks -path_delay max -sort_by_slack -group_path_count 1 -endpoint_path_count 1 -digits 6 > $out/sta_filled_max_ss/setup.rpt
report_checks -path_delay min -sort_by_slack -group_path_count 1 -endpoint_path_count 1 -digits 6 > $out/sta_filled_min_ff/hold.rpt
report_check_types -max_slew -max_capacitance -violators -digits 4 > $out/sta_filled_max_ss/electrical_violators.rpt
report_power -corner $cmax -digits 6 > $out/power_vectorless_filled_max_ss.rpt

unset_case_analysis [get_ports rst_n]
puts "FILLED_RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "FILLED_RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators -digits 4 > $out/sta_filled_max_ss/electrical_reset_visible.rpt
report_net rst_n > $out/sta_filled_max_ss/reset_net.rpt
set_case_analysis 1 [get_ports rst_n]
puts FILLED_RCX_STA_DONE
