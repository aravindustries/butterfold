# Rename core output nets to match ACH BTerms, insert diodes, incremental DRT.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set src $out/ach_ant_routed.odb
puts "ANT_SRC $src"

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
}

read_db $src
pg_connect
set block [ord::get_db_block]
set renamed 0
foreach pair {
  {din_ready_o din_ready_o_OUT}
  {dout_valid_o dout_valid_o_OUT}
  {dout[0] dout_OUT[0]} {dout[1] dout_OUT[1]} {dout[2] dout_OUT[2]} {dout[3] dout_OUT[3]}
  {dout[4] dout_OUT[4]} {dout[5] dout_OUT[5]} {dout[6] dout_OUT[6]} {dout[7] dout_OUT[7]}
} {
  lassign $pair old new
  set net [$block findNet $old]
  if {$net ne "NULL" && $net ne ""} {
    $net rename $new
    incr renamed
    puts "RENAME_NET $old -> $new"
  }
}
puts "NETS_RENAMED $renamed"
set_thread_count 16
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
file mkdir $out/antenna
puts "ANT_BEFORE [check_antennas] DIODE [diode_count]"
set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 20]
puts "REPAIR_ANTENNAS $inserted DIODE [diode_count]"
catch {detailed_placement -max_displacement {500 100}}
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
pg_connect
ensure_pad_spacing_obs
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ach_ant_incr.drc
remove_pad_spacing_obs
set ant_after [check_antennas]
puts "ANT_AFTER $ant_after DIODE [diode_count]"
if {$ant_after} {
  check_antennas -verbose -report_file $out/antenna/post_incr.rpt
}
write_db $out/ach_ant_routed.odb
write_def $out/ach_ant_routed.def
puts "WROTE_ACH_ANT_ROUTED"
exit
