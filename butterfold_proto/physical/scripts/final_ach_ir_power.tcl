set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/m2_fix
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
if {[info exists ::env(FINAL_ACH_ODB)]} {
    read_db $::env(FINAL_ACH_ODB)
} else {
    read_db $out/filled.odb
}
read_sdc $proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/final_ach.max.spef
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
puts "FINAL_IR_VDD"
analyze_power_grid -net VDD -vsrc $out/irdrop/VDD.vsrc -voltage_file $out/irdrop/final-VDD.csv
puts "FINAL_IR_VSS"
analyze_power_grid -net VSS -vsrc $out/irdrop/VSS.vsrc -voltage_file $out/irdrop/final-VSS.csv
report_power -digits 6 > $out/final_ach_vectorless_power.rpt
puts "FINAL_IR_POWER_DONE"
exit
