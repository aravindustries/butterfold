# Distributed-source IR: FULL top-layer voltage sources (padframe model).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $proto/physical/results/d03_ach_setup_eco
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $cand/butterfold_top.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $eco/hold26.max.spef
file mkdir $cand/irdrop
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
puts "IRDROP_VDD_FULL"
analyze_power_grid -net VDD -source_type FULL -voltage_file $cand/irdrop/net-VDD-full.csv
puts "IRDROP_VSS_FULL"
analyze_power_grid -net VSS -source_type FULL -voltage_file $cand/irdrop/net-VSS-full.csv
puts "IR_FULL_DONE"
exit
