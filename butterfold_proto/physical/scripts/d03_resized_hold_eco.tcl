# Hold ECO for resized ACH validation. Setup is already closed (~+3.9 ns).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set phase [expr {[info exists env(PHASE)] ? $env(PHASE) : "hold"}]
puts "HOLD_PHASE $phase"

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
  if {[catch {detailed_placement -max_displacement {2000 400}}]} {
    detailed_placement -max_displacement {5000 800}
  }
  if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_FAIL $cmsg"; exit 1 }
}

proc aoi221_2_mx {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
      set o [$inst getOrient]
      if {$o eq "MX" || $o eq "MY"} {
        incr n
        puts "AOI221_2_FAILORI [$inst getName] $o"
      }
    }
  }
  puts "AOI221_2_FAILORI_COUNT $n"
  return $n
}

if {$phase eq "hold"} {
  set c min_ff_n40C_5v50
  define_corners $c
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
  read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
  read_db $out/elec_routed.odb
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
  set exclude_file $pdk/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
  if {[file exists $exclude_file]} {
    set ef [open $exclude_file r]
    while {[gets $ef line] >= 0} {
      set line [string trim $line]
      if {$line eq "" || [string match "#*" $line]} { continue }
      set cells [get_lib_cells -quiet $line]
      if {[llength $cells]} { set_dont_use $cells }
    }
    close $ef
  }
  catch {set_dont_use [get_lib_cells *bufz_*]}
  catch {set_dont_use [get_lib_cells *antenna]}

  puts "HOLD_BEFORE"
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  puts "HOLD_VIO [sta::endpoint_violation_count min]"
  if {[catch {
    repair_timing -hold -allow_setup_violations -hold_margin 0.05 \
      -max_buffer_percent 10 -max_utilization 70 -verbose
  } msg]} { puts "HOLD_REPAIR_CAUGHT $msg" }
  puts "HOLD_AFTER"
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  puts "HOLD_VIO [sta::endpoint_violation_count min]"
  report_worst_slack -max -digits 6
  # tiny remaining cap on _16442_ if still present
  set inst [[ord::get_db_block] findInst _16442_]
  if {$inst ne "NULL"} {
    set m [[$inst getMaster] getName]
    puts "CAP_CELL $m"
  }
  legalize
  pg_connect
  aoi221_2_mx
  write_db $out/hold_eco.odb
  puts "WROTE_HOLD"
  exit 0
}

if {$phase eq "route"} {
  read_db $out/hold_eco.odb
  aoi221_2_mx
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  write_db $out/hold_grt.odb
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/hold.drc
  check_antennas
  write_db $out/hold_routed.odb
  write_def $out/hold_routed.def
  puts "HOLD_ROUTE_DONE"
  exit 0
}

puts "UNKNOWN $phase"
exit 1
