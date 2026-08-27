# IR + antenna + powered netlist on the final North/West ECO ODB.
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set eco $proto_root/physical/results/nw_pins_eco
set odb $eco/hold_eco/routed.odb
set out $eco/sta
file mkdir $out
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__tt_025C_5v00.lib
read_db $odb
puts "ANTENNA"
if {[catch {check_antennas -verbose -report_file $out/antenna.rpt} amsg]} { puts "ANTENNA $amsg" }
set n_ant 0
foreach inst [[ord::get_db_block] getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} { incr n_ant }
}
puts "ANTENNA_CELLS $n_ant"
set_pdnsim_net_voltage -net VDD -voltage 5.0
set_pdnsim_net_voltage -net VSS -voltage 0.0
puts "IR_VDD"
analyze_power_grid -net VDD -voltage_file $out/net-VDD.csv > $out/ir_vdd.rpt
puts "IR_VSS"
analyze_power_grid -net VSS -voltage_file $out/net-VSS.csv > $out/ir_vss.rpt
report_power > $out/vectorless_power.rpt
write_verilog -include_pwr_gnd $eco/hold_eco/butterfold_top.final.pnl.v
puts "IR_ANTENNA_DONE"
exit
