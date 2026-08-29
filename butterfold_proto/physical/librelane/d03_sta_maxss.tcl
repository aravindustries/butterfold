# Annotate after.max.spef onto ECO routed ODB and report max-SS.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $eco/after.max.spef
puts "SETUP_WNS"
report_wns -max
puts "SETUP_TNS"
report_tns -max
report_wns -max > $out/eco1_spef_wns.rpt
report_tns -max > $out/eco1_spef_tns.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 50 \
  > $out/eco1_spef_violations.rpt
report_checks -path_delay max -group_path_count 8 -fields {slew cap fanout net} \
  > $out/eco1_spef_paths.rpt
report_check_types -max_slew -max_cap -max_fanout -violators \
  > $out/eco1_spef_electrical.rpt
puts "SETUP_DONE"
exit
