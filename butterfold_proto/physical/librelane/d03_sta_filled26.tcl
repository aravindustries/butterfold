# RCX + max-SS/min-FF STA on filled hold26.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_filled.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $cand/filled.max.spef
read_spef $cand/filled.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]
puts "ANT"; catch {check_antennas}
puts "FILLED26_STA_DONE"
exit
