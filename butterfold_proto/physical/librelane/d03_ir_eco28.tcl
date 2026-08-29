# ACH pin-source IR on eco28 ODB. Characterization only.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $cand/butterfold_top_co6a28.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $cand/co6a28.max.spef
file mkdir $cand/irdrop
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
puts "IRDROP_VDD_ACH_VSRC"
analyze_power_grid -net VDD -vsrc $cand/irdrop/VDD.ach.csv.vsrc -voltage_file $cand/irdrop/net-VDD-eco28-vsrc.csv
puts "IRDROP_VSS_ACH_VSRC"
analyze_power_grid -net VSS -vsrc $cand/irdrop/VSS.ach.csv.vsrc -voltage_file $cand/irdrop/net-VSS-eco28-vsrc.csv
puts "IR_ECO28_DONE"
exit
