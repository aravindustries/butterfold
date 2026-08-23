set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/24pin_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__tt_025C_5v00.lib
read_db $eco/hold_eco/routed.odb
set_pdnsim_net_voltage -net VDD -voltage 5.0
set_pdnsim_net_voltage -net VSS -voltage 0.0
analyze_power_grid -net VDD -voltage_file $eco/sta/net-VDD.csv > $eco/sta/ir_vdd.rpt
analyze_power_grid -net VSS -voltage_file $eco/sta/net-VSS.csv > $eco/sta/ir_vss.rpt
report_power > $eco/sta/vectorless_power.rpt
write_verilog -include_pwr_gnd $eco/hold_eco/butterfold_top.final.pnl.v
puts "IR_NETLIST_DONE"
exit
