set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
read_db $out/butterfold_top_closed.odb
set_thread_count 16
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}
puts "ANT_BEFORE DIODE [diode_count]"
set ant [check_antennas]
puts "ANT_RC $ant"
if {$ant} {
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
  catch {detailed_placement -max_displacement {500 100}}
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ant.drc
}
puts "ANT_AFTER DIODE [diode_count]"
set ant2 [check_antennas]
puts "ANT_RC2 $ant2"
check_antennas -verbose -report_file $out/antenna/final.rpt
write_db $out/butterfold_top_closed.odb
write_def $out/butterfold_top_closed.def
puts "ANT_DONE"
