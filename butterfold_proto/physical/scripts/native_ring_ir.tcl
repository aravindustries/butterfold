# Fresh OpenRCX + PDNSim IR on the native-ring ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
set odb $out/filled.odb
if {[info exists ::env(IR_ODB)] && $::env(IR_ODB) ne ""} { set odb $::env(IR_ODB) }
read_db $odb
read_sdc $proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
set spef $out/spef/final.max.spef
if {[info exists ::env(IR_SPEF)] && $::env(IR_SPEF) ne ""} { set spef $::env(IR_SPEF) }
if {![file exists $spef]} {
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
  write_spef $spef
}
read_spef -corner $c $spef
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
file mkdir $out/irdrop
puts "NATIVE_IR_VDD"
analyze_power_grid -net VDD -vsrc $out/irdrop/VDD.vsrc -voltage_file $out/irdrop/native-VDD.csv
puts "NATIVE_IR_VSS"
analyze_power_grid -net VSS -vsrc $out/irdrop/VSS.vsrc -voltage_file $out/irdrop/native-VSS.csv
report_power -digits 6 > $out/vectorless_power.rpt
puts "NATIVE_IR_POWER_DONE"
exit
