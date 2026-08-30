# Targeted antenna diodes then LibreLane-style fill on the hold-closed ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
file mkdir $out/antenna
file mkdir $out/drt
set phase [expr {[info exists env(PHASE)] ? $env(PHASE) : "ant"}]
puts "AF_PHASE $phase"

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}

if {$phase eq "ant"} {
  read_db $out/hold_routed.odb
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  puts "ANT_BEFORE DIODE [diode_count]"
  set ant [check_antennas]
  puts "ANT_RC $ant"
  if {$ant} {
    repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
    catch {detailed_placement -max_displacement {500 100}}
    if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg"; exit 1 }
    pg_connect
    # Incremental DRT to attach diode pins. Do NOT loop.
    detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ant.drc
  }
  puts "ANT_AFTER DIODE [diode_count]"
  set ant2 [check_antennas]
  puts "ANT_RC2 $ant2"
  check_antennas -verbose -report_file $out/antenna/after_repair.rpt
  write_db $out/ant_routed.odb
  write_def $out/ant_routed.def
  puts "ANT_DONE"
  exit 0
}

if {$phase eq "fill"} {
  read_db $out/ant_diodes.odb
  set db [ord::get_db]
  set fills {}
  set decaps {}
  foreach lib [$db getLibs] {
    foreach m [$lib getMasters] {
      set n [$m getName]
      if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
      if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
    }
  }
  set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
  puts "FILL_LIST $fill_list"
  set n0 [llength [[ord::get_db_block] getInsts]]
  filler_placement $fill_list
  pg_connect
  set n1 [llength [[ord::get_db_block] getInsts]]
  puts "INST_BEFORE $n0 INST_AFTER $n1 ADDED [expr {$n1-$n0}]"
  if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
  set ant [check_antennas]
  puts "ANTENNA_CHECK $ant"
  write_db $out/filled.odb
  write_def $out/filled.def
  write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
  write_verilog $out/butterfold_top.final.v
  puts "FILL_DONE"
  exit 0
}

puts "UNKNOWN $phase"
exit 1
