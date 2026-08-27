# IR with distributed Metal4/Metal5 strap VSRC. North-edge VDD/VSS BTerms
# remain in the physical GDS; this is analysis source representation only.
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set out $proto_root/physical/results/nw_pins_eco/co6a_repair
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__tt_025C_5v00.lib
read_db $out/routed.odb
read_sdc $proto_root/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_pdnsim_net_voltage -net VDD -voltage 5.0
set_pdnsim_net_voltage -net VSS -voltage 0.0
puts "IR_VDD_DISTRIBUTED"
if {[catch {analyze_power_grid -net VDD -vsrc $out/vsrc_VDD.loc -voltage_file $out/net-VDD.csv} e]} {
  puts "IR_VDD_FAIL $e"
} else {
  puts "IR_VDD_OK"
}
puts "IR_VSS_DISTRIBUTED"
if {[catch {analyze_power_grid -net VSS -vsrc $out/vsrc_VSS.loc -voltage_file $out/net-VSS.csv} e]} {
  puts "IR_VSS_FAIL $e"
} else {
  puts "IR_VSS_OK"
}
report_power > $out/vectorless_power.rpt
if {[catch {check_antennas -report_file $out/antenna_final.rpt} amsg]} { puts "ANTENNA $amsg" }
set n_ant 0
foreach inst [[ord::get_db_block] getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n_ant }
}
puts "ANTENNA_CELLS $n_ant"
puts "IR_DONE"
exit
