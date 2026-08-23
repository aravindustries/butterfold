# Hold ECO on the 24-pin extracted-closed setup ODB.
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set eco $proto_root/physical/results/24pin_eco
set out $eco/hold_eco
file mkdir $out

set tech_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cell_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set sram_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $eco/butterfold_top_eco_routed.odb
read_sdc $proto_root/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
puts "HOLD_BEFORE"
report_wns -min
report_tns -min

repair_timing -hold -allow_setup_violations -hold_margin 0.15 \
  -max_buffer_percent 10
estimate_parasitics -placement
puts "HOLD_AFTER_REPAIR"
report_wns -min
report_tns -min

puts "HOLD_LEGALIZE"
if {[catch {detailed_placement -incremental -max_displacement {80 120}} msg]} {
  puts "INCR_FAIL $msg"
  detailed_placement
}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg" } else { puts "PLACE_OK" }
write_db $out/legal.odb

puts "HOLD_REROUTE"
set block [ord::get_db_block]
foreach net [$block getNets] {
  set st [$net getSigType]
  if {[string match *POWER* $st] || [string match *GROUND* $st]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    odb::dbWire_destroy [$net getWire]
  }
  $net clearGuides
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
global_connect
global_route -congestion_iterations 50 -verbose -guide_file $out/hold.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/hold.drc
puts "HOLD_ANTENNA"
if {[catch {repair_antennas -iterations 3} amsg]} { puts "ANTENNA_REPAIR $amsg" }
if {[catch {check_antennas -report_file $out/antenna.rpt} amsg2]} { puts "ANTENNA_CHECK $amsg2" }
write_db $out/routed.odb
write_def $out/routed.def

puts "HOLD_EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
puts "HOLD_WNS"
report_wns -min
report_tns -min
report_checks -path_delay min -slack_max 0 -group_path_count 10 > $out/hold_violations.rpt
write_spef $out/min.spef
puts "HOLD_ECO_COMPLETE"
exit
