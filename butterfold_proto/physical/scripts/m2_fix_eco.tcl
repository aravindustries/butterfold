# M2-fix extracted ECO. PHASE=sta|setup|setup_route|hold|hold_route|ant|aoi|fill
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/m2_fix
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
set lib_ff $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
set lib_sram_ff $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
file mkdir $out/drt
file mkdir $out/spef
file mkdir $out/logs
set phase sta
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "M2_PHASE $phase"

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}
proc ensure_m2_obs {} {
  set block [ord::get_db_block]
  set tech [[ord::get_db] getTech]
  set layer [$tech findLayer Metal2]
  set dbu [$block getDefUnits]
  set x2 [expr {int(2.0 * $dbu)}]
  set y2 [expr {int(65.0 * $dbu)}]
  foreach o [$block getObstructions] {
    set b [$o getBBox]
    if {[$b getTechLayer] eq $layer && [$b xMin]==0 && [$b yMin]==0 && [$b xMax]==$x2 && [$b yMax]==$y2} {
      puts "M2_OBS_PRESENT 0 0 $x2 $y2"
      return
    }
  }
  odb::dbObstruction_create $block $layer 0 0 $x2 $y2
  puts "M2_OBS_CREATED 0 0 $x2 $y2"
}
proc destroy_signal_wires {} {
  foreach net [[ord::get_db_block] getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
    catch {$net clearGuides}
  }
}
proc legalize {} {
  catch {remove_fillers}
  pg_connect
  if {[catch {detailed_placement -max_displacement {500 100}} m]} { puts "DPL $m" }
  if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
}
proc route_fresh {tag} {
  ensure_m2_obs
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $::out/drt/${tag}.drc
}
proc load_ss {odb} {
  define_corners max_ss_125C_4v50
  read_liberty -corner max_ss_125C_4v50 $::lib_ss
  read_liberty -corner max_ss_125C_4v50 $::lib_sram_ss
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  pg_connect
  ensure_m2_obs
}
proc load_ff {odb} {
  define_corners min_ff_n40C_5v50
  read_liberty -corner min_ff_n40C_5v50 $::lib_ff
  read_liberty -corner min_ff_n40C_5v50 $::lib_sram_ff
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  pg_connect
  ensure_m2_obs
}
proc extract_max {spef} {
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $::rcx_max -lef_res
  write_spef $spef
  read_spef -corner max_ss_125C_4v50 $spef
}
proc extract_min {spef} {
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $::rcx_min -lef_res
  write_spef $spef
  read_spef -corner min_ff_n40C_5v50 $spef
}
proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

if {$phase eq "sta"} {
  load_ss $out/pg.odb
  extract_max $out/spef/pg.max.spef
  puts "SETUP"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  exit 0
}

if {$phase eq "setup"} {
  load_ss $out/pg.odb
  catch {set_dont_use [get_lib_cells {*/*aoi221_2}]}
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|cts)} $n]} { catch {set_dont_touch $n} }
  }
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
  estimate_parasitics -global_routing
  puts "SETUP_BEFORE"
  report_worst_slack -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  if {[catch {
    repair_design -verbose -slew_margin 20 -cap_margin 20
  } msg]} { puts "REPAIR_DESIGN_CAUGHT $msg" }
  if {[catch {
    repair_timing -setup -repair_tns 100 -max_buffer_percent 30 -max_utilization 80 \
      -sequence sizeup -verbose
  } msg]} { puts "REPAIR_TIMING_CAUGHT $msg" }
  puts "SETUP_AFTER"
  report_worst_slack -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  legalize
  write_db $out/setup_eco.odb
  write_def $out/setup_eco.def
  puts "WROTE_SETUP_ECO"
  exit 0
}

if {$phase eq "setup_route"} {
  read_db $out/setup_eco.odb
  pg_connect
  route_fresh setup
  write_db $out/setup_routed.odb
  write_def $out/setup_routed.def
  puts "WROTE_SETUP_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "setup_sta"} {
  load_ss $out/setup_routed.odb
  extract_max $out/spef/setup_routed.max.spef
  puts "SETUP"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  exit 0
}

if {$phase eq "setup2"} {
  load_ss $out/setup_routed.odb
  catch {set_dont_use [get_lib_cells {*/*aoi221_2}]}
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|cts)} $n]} { catch {set_dont_touch $n} }
  }
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
  if {[file exists $out/spef/setup_routed.max.spef]} {
    if {[catch {read_spef -corner max_ss_125C_4v50 $out/spef/setup_routed.max.spef} m]} {
      puts "SPEF_FAIL $m"
      estimate_parasitics -global_routing
    }
  } else {
    estimate_parasitics -global_routing
  }
  puts "SETUP2_BEFORE"
  report_worst_slack -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  if {[catch {repair_design -verbose -slew_margin 30 -cap_margin 30} msg]} { puts "RD2 $msg" }
  if {[catch {
    repair_timing -setup -repair_tns 100 -max_buffer_percent 40 -max_utilization 82 -verbose
  } msg]} { puts "RT2 $msg" }
  if {[catch {
    repair_timing -setup -repair_tns 100 -max_buffer_percent 40 -max_utilization 82 \
      -sequence sizeup -verbose
  } msg]} { puts "RT2_SIZEUP $msg" }
  puts "SETUP2_AFTER"
  report_worst_slack -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  legalize
  write_db $out/setup2_eco.odb
  puts "WROTE_SETUP2"
  exit 0
}

if {$phase eq "setup2_route"} {
  read_db $out/setup2_eco.odb
  pg_connect
  route_fresh setup2
  write_db $out/setup2_routed.odb
  write_def $out/setup2_routed.def
  puts "WROTE_SETUP2_ROUTED"
  exit 0
}

if {$phase eq "setup2_sta"} {
  load_ss $out/setup2_routed.odb
  extract_max $out/spef/setup2_routed.max.spef
  puts "SETUP"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
  exit 0
}

if {$phase eq "hold"} {
  load_ff $out/setup2_routed.odb
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
  estimate_parasitics -global_routing
  puts "HOLD_BEFORE"
  report_worst_slack -min -digits 6
  if {[catch {
    repair_timing -hold -allow_setup_violations -hold_margin 0.05 \
      -max_buffer_percent 10 -max_utilization 75 -verbose
  } msg]} { puts "HOLD_CAUGHT $msg" }
  puts "HOLD_AFTER"
  report_worst_slack -min -digits 6
  legalize
  write_db $out/hold_eco.odb
  puts "WROTE_HOLD"
  exit 0
}

if {$phase eq "hold_route"} {
  read_db $out/hold_eco.odb
  pg_connect
  route_fresh hold
  write_db $out/hold_routed.odb
  write_def $out/hold_routed.def
  puts "WROTE_HOLD_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "aoi"} {
  read_db $out/hold_routed.odb
  set db [ord::get_db]
  set aoi1 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_1]
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
      set o [$inst getOrient]
      if {$o eq "MX" || $o eq "MY"} {
        $inst setPlacementStatus PLACED
        $inst swapMaster $aoi1
        incr n
        puts "SWAP_AOI [$inst getName] $o -> aoi221_1"
      }
    }
  }
  puts "SWAPPED $n"
  legalize
  route_fresh aoi
  write_db $out/aoi_routed.odb
  write_def $out/aoi_routed.def
  puts "WROTE_AOI"
  exit 0
}

if {$phase eq "ant"} {
  read_db $out/aoi_routed.odb
  pg_connect
  ensure_m2_obs
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  puts "ANT_BEFORE DIODE [diode_count]"
  set ant [check_antennas]
  puts "ANT_RC $ant"
  if {$ant} {
    repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
    catch {detailed_placement -max_displacement {500 100}}
    pg_connect
    detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ant.drc
  }
  puts "ANT_AFTER DIODE [diode_count] RC [check_antennas]"
  write_db $out/ant_routed.odb
  write_def $out/ant_routed.def
  puts "ANT_DONE"
  exit 0
}

if {$phase eq "fill"} {
  read_db $out/ant_routed.odb
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
  puts "ANTENNA_CHECK [check_antennas]"
  write_db $out/filled.odb
  write_def $out/filled.def
  write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
  write_verilog $out/butterfold_top.final.v
  puts "FILL_DONE"
  exit 0
}

puts "UNKNOWN $phase"
exit 1
