# In-session OpenRCX extract + PSM IR. Do not write_spef (STA-1670).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set odb $proto/physical/results/native_power_ring_ach/predrt/filled.odb
if {[info exists ::env(IR_ODB)] && $::env(IR_ODB) ne ""} { set odb $::env(IR_ODB) }
set out $proto/physical/results/native_power_ring_ach/predrt/ir
file mkdir $out
puts "IR_ODB $odb"
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
puts "IR_EXTRACT_DONE"
set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0
set native $proto/physical/results/native_power_ring
file mkdir $proto/physical/results/native_power_ring_ach/predrt/ir
if {![file exists $out/VDD.vsrc]} {
  file copy -force $native/irdrop/VDD.vsrc $out/VDD.vsrc
}
if {![file exists $out/VSS.vsrc]} {
  file copy -force $native/irdrop/VSS.vsrc $out/VSS.vsrc
}
puts "IR_VDD"
analyze_power_grid -net VDD -vsrc $out/VDD.vsrc -voltage_file $out/stitched-VDD.csv
puts "IR_VSS"
analyze_power_grid -net VSS -vsrc $out/VSS.vsrc -voltage_file $out/stitched-VSS.csv
puts "IR_VDD_DONE"
puts "IR_VSS_DONE"
puts "IR_DONE"
exit
