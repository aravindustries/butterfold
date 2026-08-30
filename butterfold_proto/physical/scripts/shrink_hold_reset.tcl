# Hold repair + regional rst_n tree for shrink-area, then legal GRT+DRT.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set phase [expr {[info exists env(PHASE)] ? $env(PHASE) : "hold"}]
puts "PHASE $phase"

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
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

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}

proc legalize {} {
  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  detailed_placement -max_displacement {500 100}
  if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_FAIL $cmsg"; exit 1 }
}

if {$phase eq "hold"} {
  set c min_ff_n40C_5v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
  read_db $out/butterfold_top_routed.odb
  read_sdc $sdc
  set_propagated_clock [all_clocks]
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min -lef_res
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { catch {set_dont_touch $n} }
  }
  puts "HOLD_BEFORE"
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  if {[catch {
    repair_timing -hold -allow_setup_violations -hold_margin 0.05 \
      -max_buffer_percent 10 -max_utilization 70 -verbose
  } msg]} { puts "HOLD_REPAIR_CAUGHT $msg" }
  puts "HOLD_AFTER"
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  report_worst_slack -max -digits 6
  legalize
  pg_connect
  write_db $out/hold_eco.odb
  write_def $out/hold_eco.def
  puts "WROTE_HOLD"
  exit 0
}

if {$phase eq "reset"} {
  # Connectivity-only regional rst tree. Routing is PHASE=route.
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
  read_db $out/hold_eco.odb
  read_sdc $sdc
  unset_case_analysis [get_ports rst_n]
  set db [ord::get_db]
  set block [ord::get_db_block]
  set tech [$db getTech]
  set dbu [$tech getDbUnitsPerMicron]
  set m16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
  set m8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_8]
  if {$m16 eq "NULL" || $m8 eq "NULL"} { error "missing clkbuf master" }

  set rst [$block findNet rst_n]
  set loads {}
  foreach it [$rst getITerms] {
    set inst [$it getInst]
    if {$inst eq "NULL"} { continue }
    set pin [[$it getMTerm] getName]
    if {$pin eq "Z" || $pin eq "ZN"} { continue }
    lappend loads $it
  }
  puts "RST_LOADS [llength $loads]"

  # 3x3 regions over core
  set core [$block getCoreArea]
  set x0 [$core xMin]; set y0 [$core yMin]; set x1 [$core xMax]; set y1 [$core yMax]
  set nx 3; set ny 3
  set dx [expr {($x1-$x0)/double($nx)}]
  set dy [expr {($y1-$y0)/double($ny)}]

  proc bin_xy {x y} {
    upvar x0 x0 y0 y0 dx dx dy dy nx nx ny ny
    set bx [expr {int(($x-$x0)/$dx)}]
    set by [expr {int(($y-$y0)/$dy)}]
    if {$bx < 0} { set bx 0 }
    if {$by < 0} { set by 0 }
    if {$bx >= $nx} { set bx [expr {$nx-1}] }
    if {$by >= $ny} { set by [expr {$ny-1}] }
    return [expr {$by*$nx + $bx}]
  }

  set nreg [expr {$nx*$ny}]
  for {set i 0} {$i < $nreg} {incr i} {
    set buckets($i) {}
  }
  foreach it $loads {
    set inst [$it getInst]
    set loc [$inst getLocation]
    set b [bin_xy [lindex $loc 0] [lindex $loc 1]]
    lappend buckets($b) $it
  }

  set rst_int [odb::dbNet_create $block rst_n_int]
  set root [odb::dbInst_create $block $m16 rst_root]
  # Place root near west rst_n pin (~y=1075 um)
  $root setOrient R0
  $root setLocation [expr {int(20.16*$dbu)}] [expr {int(1070*$dbu)}]
  $root setPlacementStatus PLACED
  set rootI [$root findITerm I]
  set rootZ [$root findITerm Z]
  $rootI connect $rst
  $rootZ connect $rst_int

  for {set i 0} {$i < $nreg} {incr i} {
    set net [odb::dbNet_create $block rst_n_r$i]
    set inst [odb::dbInst_create $block $m8 rst_reg$i]
    set bx [expr {$i % $nx}]
    set by [expr {$i / $nx}]
    set px [expr {int($x0 + (0.5+$bx)*$dx)}]
    set py [expr {int($y0 + (0.5+$by)*$dy)}]
    $inst setOrient R0
    $inst setLocation $px $py
    $inst setPlacementStatus PLACED
    [$inst findITerm I] connect $rst_int
    [$inst findITerm Z] connect $net
    puts "RST_REGION $i loads [llength $buckets($i)] at [expr {$px/double($dbu)}] [expr {$py/double($dbu)}]"
    foreach it $buckets($i) {
      $it disconnect
      $it connect $net
    }
  }
  pg_connect
  legalize
  write_db $out/reset_eco.odb
  write_def $out/reset_eco.def
  puts "WROTE_RESET"
  exit 0
}

if {$phase eq "route"} {
  read_db $out/reset_eco.odb
  set_thread_count 16
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  puts "GRT"
  global_route -congestion_iterations 50 -verbose -guide_file $out/hr.guide
  puts "GRT_OVERFLOW_DONE"
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
  catch {detailed_placement -max_displacement {500 100}}
  puts "DRT DIODE [diode_count]"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/hr.drc
  puts "DRT_DONE"
  check_antennas
  write_db $out/butterfold_top_closed.odb
  write_def $out/butterfold_top_closed.def
  puts "WROTE_CLOSED DIODE [diode_count]"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
