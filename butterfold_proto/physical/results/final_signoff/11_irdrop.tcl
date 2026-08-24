# Native OpenROAD analyze_power_grid (LibreLane irdrop.tcl pattern).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/butterfold_top_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/butterfold_top.max.spef
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
file mkdir $out/irdrop
puts "IRDROP_VDD"
analyze_power_grid -net VDD -voltage_file $out/irdrop/net-VDD.csv
puts "IRDROP_VSS"
analyze_power_grid -net VSS -voltage_file $out/irdrop/net-VSS.csv
puts "IRDROP_DONE"
