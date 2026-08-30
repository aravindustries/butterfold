# Extracted-aware 38.4 MHz setup ECO for the shrink-area floorplan.
# Adapted from physical/results/final_signoff/08_extracted_setup_repair.tcl
# (production methodology). Instance names from the old die are NOT replayed.
#
# Usage from butterfold_proto:
#   PHASE=rcx_max|eco|drt|sta openroad -no_init -exit physical/scripts/shrink_extracted_setup_close.tcl
#
# Default PHASE=eco after rcx_max has written SPEF.

set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
file mkdir $out
file mkdir $out/spef
file mkdir $out/drt
file mkdir $out/antenna

set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set src_odb $proto/physical/librelane/runs/shrink_area_demo/42-openroad-detailedrouting/butterfold_top.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib

set phase eco
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "SHRINK_PHASE $phase"

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

proc load_ss_sta {odb} {
  global lib_ss lib_sram_ss sdc
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $::lib_ss
  read_liberty -corner $c $::lib_sram_ss
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
}

proc protect_specials {} {
  set block [ord::get_db_block]
  foreach inst [$block getInsts] {
    set n [$inst getName]
    set m [[$inst getMaster] getName]
    if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { catch {set_dont_touch $n} }
    if {[string match "*__antenna" $m]} {
      catch {set_dont_touch $n}
      $inst setPlacementStatus FIRM
    }
    # Do not dont_touch SRAM macros: setup WNS is on SRAM D/A capture, and
    # buffering those pins is the production capture-path repair. Macros cannot
    # be resized.
  }
}

proc destroy_signal_wires {} {
  set block [ord::get_db_block]
  foreach net [$block getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
    catch {$net clearGuides}
  }
}

if {$phase eq "rcx_max"} {
  read_db $src_odb
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  write_spef $out/spef/butterfold_top.max.spef
  puts "WROTE_MAX_SPEF"
  exit 0
}

if {$phase eq "eco"} {
  load_ss_sta $src_odb
  read_spef -corner max_ss_125C_4v50 $out/spef/butterfold_top.max.spef
  protect_specials
  set block [ord::get_db_block]
  set n_before [llength [$block getInsts]]
  puts "X_BEFORE_INST $n_before"
  report_worst_slack -max -digits 6
  puts "X_BEFORE_SLEW [sta::max_slew_violation_count]"
  puts "X_BEFORE_CAP [sta::max_capacitance_violation_count]"

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

  puts "X_REPAIR_DESIGN"
  repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
  puts "X_AFTER_DESIGN_SLEW [sta::max_slew_violation_count]"
  puts "X_AFTER_DESIGN_CAP [sta::max_capacitance_violation_count]"
  report_worst_slack -max -digits 6

  puts "X_REPAIR_TIMING_SETUP"
  if {[catch {
    repair_timing -setup -verbose -setup_margin 0.1 -repair_tns 100 \
      -max_buffer_percent 5 -max_utilization 70
  } rmsg]} {
    puts "X_REPAIR_TIMING_CAUGHT $rmsg"
  }
  puts "X_AFTER_SETUP"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  report_worst_slack -min -digits 6
  puts "X_AFTER_SLEW [sta::max_slew_violation_count]"
  puts "X_AFTER_CAP [sta::max_capacitance_violation_count]"
  set n_after [llength [$block getInsts]]
  puts "X_AFTER_INST $n_after DELTA [expr {$n_after-$n_before}]"
  write_db $out/x_prelegal.odb

  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  catch {remove_fillers}
  detailed_placement -max_displacement {500 100}
  if {[catch {check_placement -verbose} cmsg]} { puts "X_PLACE $cmsg"; exit 1 }
  puts "X_CHECK_PLACEMENT_OK"
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
  foreach inst [$block getInsts] {
    set m [[$inst getMaster] getName]
    if {[string match "*__antenna" $m]} {
      catch {unset_dont_touch [$inst getName]}
      $inst setPlacementStatus PLACED
    }
  }
  set die [$block getDieArea]
  set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
  set w [expr {double([$die dx]) / $dbu}]
  set h [expr {double([$die dy]) / $dbu}]
  set die_mm2 [expr {$w * $h / 1e6}]
  puts "X_DIE ${w}x${h} MM2 $die_mm2"
  if {$w > 1110.01 || $h > 1110.01} { puts DIE_DIM_FAIL; exit 1 }
  if {$die_mm2 > 1.25} { puts DIE_AREA_FAIL; exit 1 }

  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  puts "X_GRT"
  global_route -congestion_iterations 50 -verbose -guide_file $out/x.guide
  puts "X_ANT_BEFORE DIODE [diode_count]"
  check_antennas
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
  puts "X_ANT_AFTER DIODE [diode_count]"
  check_antennas
  catch {detailed_placement -max_displacement {500 100}}
  if {[catch {check_placement -verbose} cmsg]} { puts "X_PLACE_ANT $cmsg"; exit 1 }
  write_db $out/x_grt_ant.odb
  write_def $out/x_grt_ant.def
  puts "X_PHASE_ECO_DONE"
  exit 0
}

if {$phase eq "drt"} {
  read_db $out/x_grt_ant.odb
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set max_ant_iters 8
  set i 0
  puts "DRT_RUN $i DIODE [diode_count]"
  set t0 [clock milliseconds]
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/drt-run-${i}.drc
  puts "DRT_RUNTIME_MS_$i [expr {[clock milliseconds]-$t0}]"
  write_db $out/drt/drt-run-${i}.odb
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
    detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/drt-run-${i}.drc
    puts "DRT_RUNTIME_MS_$i [expr {[clock milliseconds]-$t0}]"
    write_db $out/drt/drt-run-${i}.odb
    incr i
  }
  puts "FINAL_ANTENNA DIODE [diode_count]"
  check_antennas -verbose -report_file $out/antenna/post_drt.rpt
  write_db $out/butterfold_top_routed.odb
  write_def $out/butterfold_top_routed.def
  puts "WROTE_FINAL_ROUTE DIODE [diode_count]"
  exit 0
}

if {$phase eq "sta"} {
  load_ss_sta $out/butterfold_top_routed.odb
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  write_spef $out/spef/butterfold_top.max.spef
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  puts "SETUP_VIO [sta::endpoint_violation_count max]"
  puts "SLEW [sta::max_slew_violation_count]"
  puts "CAP [sta::max_capacitance_violation_count]"
  report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 \
    > $out/electrical_case.rpt
  unset_case_analysis [get_ports rst_n]
  puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
  puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
  report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 \
    > $out/electrical_reset_visible.rpt
  report_net rst_n > $out/reset_net.rpt
  puts "STA_DONE"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
