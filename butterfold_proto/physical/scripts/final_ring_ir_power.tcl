# Quantitative IR on the accepted post-bar-removal power-ring topology.
# Does not modify the ODB/DEF/GDS. Writes SPEF/CSV under irdrop_final_ring/.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/m2_fix
set irdir $out/irdrop_final_ring
set pdk /foss/pdks/gf180mcuD
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set c max_ss_125C_4v50
file mkdir $irdir
file mkdir $irdir/spef

define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/power_ring.odb
read_sdc $proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect

puts "FINAL_RING_IR_EXTRACT_START"
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file $rcx_max -lef_res
write_spef $irdir/spef/power_ring.max.spef
read_spef -corner $c $irdir/spef/power_ring.max.spef
puts "FINAL_RING_IR_EXTRACT_DONE"

set_pdnsim_net_voltage -net VDD -voltage 4.5
set_pdnsim_net_voltage -net VSS -voltage 0

puts "FINAL_RING_PSM_VDD"
check_power_grid -net VDD
puts "FINAL_RING_PSM_VSS"
check_power_grid -net VSS

puts "FINAL_RING_IR_VDD"
analyze_power_grid -net VDD -vsrc $out/irdrop/VDD.vsrc -voltage_file $irdir/final-ring-VDD.csv
puts "FINAL_RING_IR_VSS"
analyze_power_grid -net VSS -vsrc $out/irdrop/VSS.vsrc -voltage_file $irdir/final-ring-VSS.csv
report_power -digits 6 > $irdir/vectorless_power.rpt
puts "FINAL_RING_IR_POWER_DONE"
exit
