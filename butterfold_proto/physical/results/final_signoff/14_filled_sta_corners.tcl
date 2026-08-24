# Single-corner electrical confirmation on filled SPEFs.
# Dual-corner max_slew_violation_count mixed max-SS and min-FF.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff

puts "CORNER_MAX_SS"
define_corners max_ss_125C_4v50
read_liberty -corner max_ss_125C_4v50 /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner max_ss_125C_4v50 /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/butterfold_top_filled.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner max_ss_125C_4v50 $out/spef_filled/butterfold_top.max.spef
puts "MAX_SS_SLEW [sta::max_slew_violation_count]"
puts "MAX_SS_CAP [sta::max_capacitance_violation_count]"
report_worst_slack -max -digits 6
report_tns -max -digits 6
report_check_types -max_slew -max_capacitance -violators -digits 4 > $out/sta_filled_max_ss/electrical_violators_ss_only.rpt
unset_case_analysis [get_ports rst_n]
puts "MAX_SS_RESET_SLEW [sta::max_slew_violation_count]"
puts "MAX_SS_RESET_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators -digits 4 > $out/sta_filled_max_ss/electrical_reset_visible_ss_only.rpt
set_case_analysis 1 [get_ports rst_n]
puts "CORNER_MAX_SS_DONE"
exit 0
