# Extracted-aware ECO for the native PDN_CORE_RING rehardening.
# Methodology: shrink_extracted_setup_close.tcl + m2_fix_eco.tcl pad-spacing
# obstructions. Instance-name ECOs from the pre-ring netlist are NOT replayed.
#
# Usage:
#   PHASE=rcx_max|eco|drt|sta|hold|hold_route|fill \
#     openroad -no_init -exit physical/scripts/native_ring_eco.tcl
#
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring
if {[info exists env(ECO_OUTDIR)] && $env(ECO_OUTDIR) ne ""} {
  set out $env(ECO_OUTDIR)
}
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set src_odb $proto/physical/librelane/runs/native_pdn_ring/44-odb-reportdisconnectedpins/butterfold_top.odb
if {[info exists env(ECO_SRC)] && $env(ECO_SRC) ne ""} {
  set src_odb $env(ECO_SRC)
}
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
set lib_ff $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
set lib_sram_ff $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
file mkdir $out
file mkdir $out/spef
file mkdir $out/drt
file mkdir $out/antenna
file mkdir $out/logs

set phase eco
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "NATIVE_RING_PHASE $phase"
puts "ECO_SRC $src_odb"
puts "ECO_OUTDIR $out"

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

proc ensure_pad_spacing_obs {} {
  set organizer "$::proto/physical/reports/m2_fix/evidence/organizer/D03_ACH.def"
  set intended {
    VSS clk rst_n din_valid_i din[7] din[6] din[5] din[4] din[3] din[2] din[1] din[0]
    din_ready_o_OUT dout_valid_o_OUT dout_OUT[7] dout_OUT[6] dout_OUT[5] dout_OUT[4]
    dout_OUT[3] dout_OUT[2] dout_OUT[1] dout_OUT[0] VDD
  }
  set fh [open $organizer r]
  set text [read $fh]
  close $fh
  set block [ord::get_db_block]
  set layer [[[ord::get_db] getTech] findLayer Metal2]
  set dbu [$block getDefUnits]
  set scale [expr {$dbu / 200.0}]
  set halo 0
  set die [$block getDieArea]
  set current ""
  set created 0
  set ::pad_spacing_obs {}
  foreach line [split $text "\n"] {
    if {[regexp {^- ([^ ]+) } $line -> name]} { set current $name }
    if {$current eq "" || [lsearch -exact $intended $current] >= 0} { continue }
    if {[regexp {^[[:space:]]*\+ LAYER Metal2 \( (-?[0-9]+) (-?[0-9]+) \) \( (-?[0-9]+) (-?[0-9]+) \)} $line -> ax1 ay1 ax2 ay2]} {
      set x1 [expr {max([$die xMin], int($ax1*$scale)-$halo)}]
      set y1 [expr {max([$die yMin], int($ay1*$scale)-$halo)}]
      set x2 [expr {min([$die xMax], int($ax2*$scale)+$halo)}]
      set y2 [expr {min([$die yMax], int($ay2*$scale)+$halo)}]
      set obs [odb::dbObstruction_create $block $layer $x1 $y1 $x2 $y2]
      lappend ::pad_spacing_obs $obs
      incr created
    }
  }
  puts "PAD_SPACING_OBSTRUCTIONS $created GEOMETRY EXACT RULES M2.2a/M2.2b_ROUTER_APPLIED"
}

proc remove_pad_spacing_obs {} {
  if {![info exists ::pad_spacing_obs]} { return }
  set removed 0
  foreach obs $::pad_spacing_obs {
    odb::dbObstruction_destroy $obs
    incr removed
  }
  set ::pad_spacing_obs {}
  puts "PAD_SPACING_PLANNING_OBSTRUCTIONS_REMOVED $removed"
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

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

proc protect_specials {} {
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    set m [[$inst getMaster] getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|cts)} $n]} { catch {set_dont_touch $n} }
    if {[string match "*__antenna" $m]} {
      catch {set_dont_touch $n}
      $inst setPlacementStatus FIRM
    }
  }
}

proc apply_dont_use {} {
  set exclude_file $::pdk/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
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
  catch {set_dont_use [get_lib_cells {*/*aoi221_2}]}
}

proc legalize {} {
  catch {remove_fillers}
  pg_connect
  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  if {[catch {detailed_placement -max_displacement {2000 400}} m]} {
    puts "DPL_RETRY $m"
    detailed_placement -max_displacement {5000 800}
  }
  if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
  puts "CHECK_PLACEMENT_OK"
}

proc load_ss {odb} {
  define_corners max_ss_125C_4v50
  read_liberty -corner max_ss_125C_4v50 $::lib_ss
  read_liberty -corner max_ss_125C_4v50 $::lib_sram_ss
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
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
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
  pg_connect
  ensure_m2_obs
}

if {$phase eq "rcx_max"} {
  read_db $src_odb
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  write_spef $out/spef/pre_eco.max.spef
  puts "WROTE_MAX_SPEF $out/spef/pre_eco.max.spef"
  exit 0
}

if {$phase eq "eco"} {
  load_ss $src_odb
  set spef $out/spef/pre_eco.max.spef
  if {![file exists $spef]} {
    puts "MISSING_SPEF $spef"
    exit 1
  }
  read_spef -corner max_ss_125C_4v50 $spef
  protect_specials
  apply_dont_use
  set block [ord::get_db_block]
  puts "X_BEFORE_INST [llength [$block getInsts]]"
  if {[catch {puts "X_BEFORE_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"} m]} {
    puts "X_BEFORE_SLEW_CAP_CAUGHT $m"
  }
  report_worst_slack -max -digits 6
  report_tns -max -digits 6

  puts "X_REPAIR_DESIGN"
  if {[catch {
    repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
  } rmsg]} { puts "X_REPAIR_DESIGN_CAUGHT $rmsg" }
  if {[catch {puts "X_AFTER_DESIGN_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"} m]} {
    puts "X_AFTER_DESIGN_SLEW_CAP_CAUGHT $m"
  }
  report_worst_slack -max -digits 6

  puts "X_REPAIR_TIMING_SETUP"
  if {[catch {
    repair_timing -setup -verbose -setup_margin 0.1 -repair_tns 100 \
      -max_buffer_percent 30 -max_utilization 80
  } rmsg]} { puts "X_REPAIR_TIMING_CAUGHT $rmsg" }
  if {[catch {
    repair_timing -setup -verbose -setup_margin 0.1 -repair_tns 100 \
      -max_buffer_percent 30 -max_utilization 80 -sequence sizeup
  } rmsg]} { puts "X_REPAIR_TIMING_SIZEUP_CAUGHT $rmsg" }
  puts "X_AFTER_SETUP"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  report_worst_slack -min -digits 6
  if {[catch {puts "X_AFTER_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"} m]} {
    puts "X_AFTER_SLEW_CAP_CAUGHT $m"
  }
  puts "X_AFTER_INST [llength [$block getInsts]]"
  write_db $out/x_prelegal.odb

  legalize
  foreach inst [$block getInsts] {
    set m [[$inst getMaster] getName]
    if {[string match "*__antenna" $m]} {
      catch {unset_dont_touch [$inst getName]}
      $inst setPlacementStatus PLACED
    }
  }

  ensure_pad_spacing_obs
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  set_thread_count 16
  puts "X_GRT"
  global_route -congestion_iterations 50 -verbose -guide_file $out/x.guide
  puts "X_ANT_BEFORE DIODE [diode_count]"
  check_antennas
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
  puts "X_ANT_AFTER DIODE [diode_count]"
  check_antennas
  catch {detailed_placement -max_displacement {500 100}}
  if {[catch {check_placement -verbose} cmsg]} { puts "X_PLACE_ANT $cmsg"; exit 1 }
  remove_pad_spacing_obs
  write_db $out/x_grt_ant.odb
  write_def $out/x_grt_ant.def
  puts "X_PHASE_ECO_DONE"
  exit 0
}

if {$phase eq "drt"} {
  read_db $out/x_grt_ant.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
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
  remove_pad_spacing_obs
  puts "FINAL_ANTENNA DIODE [diode_count]"
  check_antennas -verbose -report_file $out/antenna/post_drt.rpt
  write_db $out/butterfold_top_routed.odb
  write_def $out/butterfold_top_routed.def
  puts "WROTE_FINAL_ROUTE DIODE [diode_count]"
  exit 0
}

if {$phase eq "sta"} {
  load_ss $out/butterfold_top_routed.odb
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_max -lef_res
  write_spef $out/spef/routed.max.spef
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  if {[catch {puts "SETUP_VIO [sta::endpoint_violation_count max]"} m]} { puts "SETUP_VIO_CAUGHT $m" }
  if {[catch {puts "SLEW [sta::max_slew_violation_count]"} m]} { puts "SLEW_CAUGHT $m" }
  if {[catch {puts "CAP [sta::max_capacitance_violation_count]"} m]} { puts "CAP_CAUGHT $m" }
  report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 \
    > $out/electrical_case.rpt
  catch {unset_case_analysis [get_ports rst_n]}
  puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
  puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
  report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 \
    > $out/electrical_reset_visible.rpt
  report_net rst_n > $out/reset_net.rpt
  puts "STA_DONE"
  exit 0
}

if {$phase eq "hold"} {
  set hold_src $out/rst_routed.odb
  if {[info exists env(ECO_SRC)] && $env(ECO_SRC) ne ""} { set hold_src $env(ECO_SRC) }
  puts "HOLD_SRC $hold_src"
  load_ff $hold_src
  define_process_corner -ext_model_index 0 CURRENT_CORNER
  extract_parasitics -ext_model_file $rcx_min -lef_res
  write_spef $out/spef/routed.min.spef
  read_spef -corner min_ff_n40C_5v50 $out/spef/routed.min.spef
  protect_specials
  apply_dont_use
  puts "HOLD_BEFORE"
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
  if {[catch {
    repair_timing -hold -allow_setup_violations -hold_margin 0.05 \
      -max_buffer_percent 10 -max_utilization 80 -verbose
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
  ensure_m2_obs
  ensure_pad_spacing_obs
  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  global_route -congestion_iterations 50 -verbose
  remove_pad_spacing_obs
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/hold.drc
  write_db $out/hold_routed.odb
  write_def $out/hold_routed.def
  puts "WROTE_HOLD_ROUTED DIODE [diode_count]"
  exit 0
}

if {$phase eq "fill"} {
  set src $out/butterfold_top_routed.odb
  if {[info exists env(FILL_SRC)] && $env(FILL_SRC) ne ""} { set src $env(FILL_SRC) }
  read_db $src
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
  if {[catch {check_placement -verbose} m]} { puts "PLACE $m" }
  write_db $out/filled.odb
  write_def $out/filled.def
  write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
  write_verilog $out/butterfold_top.final.v
  puts "FILL_DONE"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
