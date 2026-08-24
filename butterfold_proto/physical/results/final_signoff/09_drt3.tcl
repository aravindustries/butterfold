set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
file mkdir $out/drt3
read_db $out/x_grt_ant.odb
set_thread_count 22
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}
set max_ant_iters 8
set i 0
puts "DRT_RUN $i DIODE [diode_count]"
set t0 [clock milliseconds]
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt3/drt-run-${i}.drc
puts "DRT_RUNTIME_MS_$i [expr {[clock milliseconds]-$t0}]"
write_db $out/drt3/drt-run-${i}.odb
incr i
while {$i <= $max_ant_iters} {
  puts "CHECK_ANTENNAS_ITER $i DIODE [diode_count]"
  set ant [check_antennas]
  puts "CHECK_ANTENNAS_RC $ant"
  if {!$ant} { puts "ANTENNA_PASS_AFTER_DRT_ITER [expr {$i-1}]"; break }
  set d0 [diode_count]
  set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
  set d1 [diode_count]
  puts "REPAIR_ANTENNAS_RETURN $inserted DIODE $d0 -> $d1"
  if {!$inserted && ($d1 == $d0)} { puts "NO_DIODES_ENDING"; break }
  catch {detailed_placement -max_displacement {500 100}}
  catch {check_placement -verbose}
  puts "DRT_RUN $i"
  set t0 [clock milliseconds]
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt3/drt-run-${i}.drc
  puts "DRT_RUNTIME_MS_$i [expr {[clock milliseconds]-$t0}]"
  write_db $out/drt3/drt-run-${i}.odb
  incr i
}
puts "FINAL_ANTENNA DIODE [diode_count]"
check_antennas -verbose -report_file $out/antenna/final3_verbose.rpt
write_db $out/butterfold_top_routed.odb
write_def $out/butterfold_top_routed.def
puts "WROTE_FINAL_ROUTE DIODE [diode_count]"
puts "PHASE3_DONE"
