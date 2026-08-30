set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
read_db $out/butterfold_top_closed.odb
set db [ord::get_db]
set block [ord::get_db_block]
proc swap {name master} {
  set inst [[ord::get_db_block] findInst $name]
  set m [[ord::get_db] findMaster $master]
  if {$inst eq "NULL" || $m eq "NULL"} { error "swap $name $master" }
  $inst swapMaster $m
  puts "SWAP $name $master"
}
swap rst_root gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
foreach i {0 1 3 4} {
  swap rst_reg$i gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
}
swap _12569_ gf180mcu_fd_sc_mcu9t5v0__oai32_2
swap _15762_ gf180mcu_fd_sc_mcu9t5v0__oai21_2
set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {2000 400}}]} {
  puts "PLACE_RETRY"
  detailed_placement -max_displacement {5000 800}
}
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
set_thread_count 16
global_route -congestion_iterations 50 -verbose
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
catch {detailed_placement -max_displacement {500 100}}
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/elec.drc
set ant [check_antennas]
puts "ANT $ant"
if {$ant} {
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
  catch {detailed_placement -max_displacement {500 100}}
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/elec2.drc
  set ant [check_antennas]
  puts "ANT2 $ant"
}
write_db $out/butterfold_top_closed.odb
write_def $out/butterfold_top_closed.def
puts "ELEC_FIX_DONE"
