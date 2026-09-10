# Incremental DRT + antenna loop from RST_SRC (default rst_grt.odb).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring
set src $out/rst_grt.odb
if {[info exists env(RST_SRC)] && $env(RST_SRC) ne ""} { set src $env(RST_SRC) }
set dst $out/rst_routed.odb
if {[info exists env(RST_DST)] && $env(RST_DST) ne ""} { set dst $env(RST_DST) }
puts "DRT_SRC $src"

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
ensure_pad_spacing_obs
set_thread_count 16
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set i 0
set max_ant_iters 8
puts "DRT_RUN $i DIODE [diode_count]"
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/rst-${i}.drc
incr i
while {$i <= $max_ant_iters} {
  set ant [check_antennas]
  puts "CHECK_ANTENNAS_ITER $i RC $ant DIODE [diode_count]"
  if {!$ant} { puts "ANTENNA_PASS"; break }
  set d0 [diode_count]
  set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
  set d1 [diode_count]
  puts "REPAIR_ANTENNAS $inserted DIODE $d0 -> $d1"
  if {!$inserted && ($d1 == $d0)} { puts "NO_DIODES_ENDING"; break }
  catch {detailed_placement -max_displacement {500 100}}
  puts "DRT_RUN $i"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/rst-${i}.drc
  incr i
}
remove_pad_spacing_obs
check_antennas -verbose -report_file $out/antenna/rst_post_drt.rpt
write_db $dst
write_def [file rootname $dst].def
puts "WROTE_RST_ROUTED DIODE [diode_count]"
exit
