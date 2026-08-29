# min-FF hold on best setup checkpoint teco12.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $src/butterfold_top_co6a36_teco12.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
catch {set_thread_count 22}
puts "EXTRACT_MIN"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
write_spef $src/teco12.min.spef
read_spef $src/teco12.min.spef
puts "HOLD_WNS"; report_wns -min
puts "HOLD_TNS"; report_tns -min
report_wns -min > $src/hold_wns.rpt
report_tns -min > $src/hold_tns.rpt
puts "TECO12_HOLD_DONE"
exit
