# eco36 extracted max-SS setup + electrical, then min-FF hold.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_candidate/co6a36
set out $proto/physical/reports/signoff/evidence/d03_ach
file mkdir $out/setup
file mkdir $eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_co6a36_filled_pg.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_max_fanout 10 [current_design]

puts "EXTRACT_MAX"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $eco/co6a36.max.spef
read_spef $eco/co6a36.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
report_wns -max > $out/setup/co6a36_setup_wns.rpt
report_tns -max > $out/setup/co6a36_setup_tns.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 20 > $out/setup/co6a36_setup_violations.rpt
report_check_types -max_slew -max_cap -max_fanout -violators > $out/setup/co6a36_electrical.rpt
puts "SLEW_COUNT [sta::max_slew_violation_count]"
puts "CAP_COUNT [sta::max_capacitance_violation_count]"
puts "FANOUT_COUNT [sta::max_fanout_violation_count]"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]
puts "ECO36_STA_MAX_DONE"
exit
