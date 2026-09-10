# Apply the YAML-defined ACH integration shell onto the accepted native-ring
# ODB. Does not regenerate PDN. Signal reroute is only for new shell nets
# unless incremental routing cannot close.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set src $proto/physical/results/native_power_ring/filled.odb
set out $proto/physical/results/native_power_ring_ach
set shell $out/final_ach_shell.tcl
file mkdir $out
file mkdir $out/drt
set phase apply
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "NATIVE_ACH_PHASE $phase"

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}
proc ensure_m2_obs {} {
  set block [ord::get_db_block]
  set layer [[[ord::get_db] getTech] findLayer Metal2]
  set dbu [$block getDefUnits]
  set x2 [expr {int(2.0 * $dbu)}]
  set y2 [expr {int(65.0 * $dbu)}]
  foreach o [$block getObstructions] {
    set b [$o getBBox]
    if {[$b getTechLayer] eq $layer && [$b xMin]==0 && [$b yMin]==0 && [$b xMax]==$x2 && [$b yMax]==$y2} { return }
  }
  odb::dbObstruction_create $block $layer 0 0 $x2 $y2
}
proc ensure_pad_spacing_obs {} {
  set organizer "$::proto/physical/reports/native_power_ring_ach/evidence/D03_ACH.def"
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
  set die [$block getDieArea]
  set current ""
  set ::pad_spacing_obs {}
  set created 0
  foreach line [split $text "\n"] {
    if {[regexp {^- ([^ ]+) } $line -> name]} { set current $name }
    if {$current eq "" || [lsearch -exact $intended $current] >= 0} { continue }
    if {[regexp {^[[:space:]]*\+ LAYER Metal2 \( (-?[0-9]+) (-?[0-9]+) \) \( (-?[0-9]+) (-?[0-9]+) \)} $line -> ax1 ay1 ax2 ay2]} {
      set x1 [expr {max([$die xMin], int($ax1*$scale))}]
      set y1 [expr {max([$die yMin], int($ay1*$scale))}]
      set x2 [expr {min([$die xMax], int($ax2*$scale))}]
      set y2 [expr {min([$die yMax], int($ay2*$scale))}]
      lappend ::pad_spacing_obs [odb::dbObstruction_create $block $layer $x1 $y1 $x2 $y2]
      incr created
    }
  }
  puts "PAD_SPACING_OBSTRUCTIONS $created"
}
proc remove_pad_spacing_obs {} {
  if {![info exists ::pad_spacing_obs]} { return }
  foreach obs $::pad_spacing_obs { catch {odb::dbObstruction_destroy $obs} }
  set ::pad_spacing_obs {}
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

if {$phase eq "apply"} {
  read_db $src
  catch {remove_fillers}
  pg_connect
  ensure_m2_obs
  puts "BTERMS_BEFORE [llength [[ord::get_db_block] getBTerms]]"
  source $shell
  puts "BTERMS_AFTER [llength [[ord::get_db_block] getBTerms]]"
  set skip_dpl 0
  if {[info exists env(SKIP_DPL)] && $env(SKIP_DPL) eq "1"} { set skip_dpl 1 }
  if {$skip_dpl} {
    puts "SKIP_DPL 1"
  } else {
    set_placement_padding -global -left 1 -right 1
    if {[catch {detailed_placement -max_displacement {5000 800}} m]} {
      puts "DPL_RETRY $m"
      detailed_placement -max_displacement {8000 1200}
    }
    if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
    puts "CHECK_PLACEMENT_OK"
  }
  pg_connect
  set dst_odb $out/ach_applied.odb
  set dst_def $out/ach_applied.def
  if {[info exists env(APPLY_DST)] && $env(APPLY_DST) ne ""} {
    set dst_odb $env(APPLY_DST)
    set dst_def [file rootname $dst_odb].def
  }
  write_db $dst_odb
  write_def $dst_def
  puts "WROTE_ACH_APPLIED $dst_odb"
  exit 0
}

if {$phase eq "route_incr"} {
  read_db $out/ach_applied.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  puts "GRT_INCR"
  global_route -congestion_iterations 80 -verbose
  puts "DRT_INCR DIODE [diode_count]"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ach_incr.drc
  remove_pad_spacing_obs
  puts "ANT [check_antennas] DIODE [diode_count]"
  write_db $out/ach_routed.odb
  write_def $out/ach_routed.def
  puts "WROTE_ACH_ROUTED"
  exit 0
}

if {$phase eq "route_fresh"} {
  read_db $out/ach_applied.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  destroy_signal_wires
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  puts "GRT_FRESH"
  global_route -congestion_iterations 80 -verbose
  puts "DRT_FRESH DIODE [diode_count]"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ach_fresh.drc
  remove_pad_spacing_obs
  puts "ANT [check_antennas] DIODE [diode_count]"
  write_db $out/ach_routed.odb
  write_def $out/ach_routed.def
  puts "WROTE_ACH_ROUTED"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
