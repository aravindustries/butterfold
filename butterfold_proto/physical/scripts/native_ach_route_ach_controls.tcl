# Route only the remaining unrouted ACH tie nets on the M3-cut native-wire ODB.
# Does not destroy existing signal wires. Does not regenerate PDN.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach/predrt
set src $out/applied_m3cut_guided.odb
if {[info exists env(ROUTE_SRC)] && $env(ROUTE_SRC) ne ""} { set src $env(ROUTE_SRC) }
puts "ROUTE_SRC $src"
file mkdir $out/drt

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}
proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}
proc wire_events {name} {
  set net [[ord::get_db_block] findNet $name]
  if {$net eq "NULL" || $net eq ""} { return none }
  set w [$net getWire]
  if {$w eq "NULL" || $w eq ""} { return 0 }
  return has
}
proc count_unrouted {} {
  set u 0
  set ach_u 0
  foreach net [[ord::get_db_block] getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w eq "NULL" || $w eq ""} {
      incr u
      set n [$net getName]
      if {[string match "ach_*" $n]} { incr ach_u }
    }
  }
  puts "UNROUTED_SIGNAL $u UNROUTED_ACH $ach_u"
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
  puts "PAD_SPACING_OBSTRUCTIONS [llength $::pad_spacing_obs]"
}
proc remove_pad_spacing_obs {} {
  if {![info exists ::pad_spacing_obs]} { return }
  foreach obs $::pad_spacing_obs { catch {odb::dbObstruction_destroy $obs} }
}

read_db $src
pg_connect
puts "BTERMS [llength [[ord::get_db_block] getBTerms]]"
puts "CLK_WIRE [wire_events clk] _07203_ [wire_events _07203_] CS [wire_events ach_din_ready_o_CS_tie0]"
count_unrouted
ensure_pad_spacing_obs
set_thread_count 16
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
puts "DRT_ACH_CONTROLS DIODE [diode_count]"
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ach_controls.drc} m]} {
  puts "DRT_FAIL $m"
  write_db $out/applied_m3cut_controls_fail.odb
  exit 1
}
remove_pad_spacing_obs
puts "CLK_WIRE_AFTER [wire_events clk] _07203_ [wire_events _07203_] CS [wire_events ach_din_ready_o_CS_tie0]"
count_unrouted
set ant [check_antennas]
puts "ANT_AFTER $ant DIODE [diode_count]"
if {$ant} {
  check_antennas -verbose -report_file $out/ach_controls_ant.rpt
}
write_db $out/applied_m3cut_controls.odb
write_def $out/applied_m3cut_controls.def
puts "WROTE_ACH_CONTROLS"
exit
