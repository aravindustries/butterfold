# Classify electrical violations on teco18. Reuse max SPEF. No ECO.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src/butterfold_top_co6a36_teco18.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
catch {set_thread_count 22}
read_spef $src/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "LIBERTY_SLEW [sta::max_slew_violation_count]"
puts "LIBERTY_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_cap -violators > $src/elec_liberty_violators.rpt
# design limits used in earlier ECO logs
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
puts "DESIGN_SLEW [sta::max_slew_violation_count]"
puts "DESIGN_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_cap -violators > $src/elec_design_violators.rpt
# reset-visible (liberty+design limits still applied)
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_cap -violators > $src/elec_reset_visible.rpt
set_case_analysis 1 [get_ports rst_n]
puts "TECO18_ELEC_CLASSIFY_DONE"
exit
