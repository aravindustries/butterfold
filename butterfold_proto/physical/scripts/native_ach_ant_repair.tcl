# Targeted antenna repair for ACH-shell routed ODB. Writes only under
# native_power_ring_ach/. Does not touch native-power-ring artifacts.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set src $out/ach_routed.odb
if {[info exists env(ANT_SRC)] && $env(ANT_SRC) ne ""} { set src $env(ANT_SRC) }
puts "ANT_SRC $src"
file mkdir $out/drt
file mkdir $out/antenna

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
  foreach line [split $text "\n"] {
    if {[regexp {^- ([^ ]+) } $line -> name]} { set current $name }
    if {$current eq "" || [lsearch -exact $intended $current] >= 0} { continue }
    if {[regexp {^[[:space:]]*\+ LAYER Metal2 \( (-?[0-9]+) (-?[0-9]+) \) \( (-?[0-9]+) (-?[0-9]+) \)} $line -> ax1 ay1 ax2 ay2]} {
      set x1 [expr {max([$die xMin], int($ax1*$scale))}]
      set y1 [expr {max([$die yMin], int($ay1*$scale))}]
      set x2 [expr {min([$die xMax], int($ax2*$scale))}]
      set y2 [expr {min([$die yMax], int($ay2*$scale))}]
      lappend ::pad_spacing_obs [odb::dbObstruction_create $block $layer $x1 $y1 $x2 $y2]
    }
  }
}
proc remove_pad_spacing_obs {} {
  if {![info exists ::pad_spacing_obs]} { return }
  foreach obs $::pad_spacing_obs { catch {odb::dbObstruction_destroy $obs} }
  set ::pad_spacing_obs {}
}
proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

read_db $src
pg_connect
ensure_m2_obs
set_thread_count 16
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
puts "ANT_BEFORE DIODE [diode_count]"
set ant [check_antennas]
puts "ANT_BEFORE_RC $ant"
set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
puts "REPAIR_ANTENNAS_RETURN $inserted DIODE [diode_count]"
catch {detailed_placement -max_displacement {500 100}}
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
pg_connect
# Incremental DRT after pin rename fails checkConnectivity on core
# output nets (BTerm dout_OUT[n] / net dout[n]). Re-route signals only;
# PDN special nets are preserved.
foreach net [[ord::get_db_block] getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}
ensure_pad_spacing_obs
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
global_route -congestion_iterations 80 -verbose
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ach_ant.drc
remove_pad_spacing_obs
set ant [check_antennas]
puts "ANT_AFTER_RC $ant DIODE [diode_count]"
write_db $out/ach_ant_routed.odb
write_def $out/ach_ant_routed.def
puts "WROTE_ACH_ANT_ROUTED"
exit
