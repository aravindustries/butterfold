# Dump the six remaining extracted max-SS paths from teco12. No ECO.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16
puts "SRC $src/butterfold_top_co6a36_teco12.odb"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src/butterfold_top_co6a36_teco12.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
read_spef $src/after.max.spef

puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
report_checks -path_delay max -slack_max 0 -group_path_count 20 -fields {slew cap fanout net} \
  > $src/six_violators.rpt
report_checks -path_delay max -group_path_count 8 -fields {slew cap fanout net} \
  > $src/six_top8.rpt
puts "WROTE $src/six_violators.rpt"
puts "SIX_DUMP_DONE"
exit
