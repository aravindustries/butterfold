set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set eco $proto_root/physical/results/24pin_eco
set out $eco/sta
file mkdir $out
set tech_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cell_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set sram_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $eco/butterfold_top_eco_routed.odb
read_sdc $proto_root/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $eco/after.min.spef
report_wns -min > $out/minff_wns.rpt
report_tns -min > $out/minff_tns.rpt
report_checks -path_delay min -group_path_count 10 -fields {slew cap fanout net} \
  > $out/minff_hold_paths.rpt
report_checks -path_delay min -slack_max 0 -group_path_count 50 \
  > $out/minff_hold_violations.rpt
report_clock_skew -hold > $out/minff_skew.rpt
puts "WNS_HOLD"
report_wns -min
puts "TNS_HOLD"
report_tns -min
exit
