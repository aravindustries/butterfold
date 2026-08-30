set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/filled.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/butterfold_top.max.spef
file mkdir $out/irdrop
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
puts "IRDROP_VDD_VSRC"
analyze_power_grid -net VDD -vsrc $out/irdrop/VDD.vsrc -voltage_file $out/irdrop/net-VDD-vsrc.csv
puts "IRDROP_VSS_VSRC"
analyze_power_grid -net VSS -vsrc $out/irdrop/VSS.vsrc -voltage_file $out/irdrop/net-VSS-vsrc.csv
report_power -digits 6 > $out/power_vectorless_max_ss.rpt
puts "IR_POWER_DONE"
exit
