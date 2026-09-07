# Buffer rst_n / slew after hold re-route. LibreLane had
# RUN_POST_GPL_DESIGN_REPAIR false, so the port still drives ~1460 loads.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set src $out/ant_routed.odb
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib

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

define_corners max_ss_125C_4v50
read_liberty -corner max_ss_125C_4v50 $lib_ss
read_liberty -corner max_ss_125C_4v50 $lib_sram_ss
read_db $src
read_sdc $sdc
set_propagated_clock [all_clocks]
pg_connect
ensure_m2_obs
catch {unset_case_analysis rst_n}
catch {unset_case_analysis [get_ports rst_n]}
foreach inst [[ord::get_db_block] getInsts] {
  set n [$inst getName]
  if {[regexp {^(clkbuf|delaybuf|clkload|cts)} $n]} { catch {set_dont_touch $n} }
}
catch {set_dont_use [get_lib_cells *bufz_*]}
catch {set_dont_use [get_lib_cells *antenna]}
catch {set_dont_use [get_lib_cells {*/*aoi221_2}]}

destroy_signal_wires
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
set_thread_count 16
ensure_pad_spacing_obs
global_route -congestion_iterations 50 -verbose
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
estimate_parasitics -global_routing
puts "E_BEFORE_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
report_worst_slack -max -digits 6
report_net rst_n > $out/logs/rst_n_before_repair.rpt
puts "E_REPAIR_DESIGN"
if {[catch {repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20} m]} {
  puts "E_REPAIR_DESIGN_CAUGHT $m"
}
puts "E_AFTER_DESIGN_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
report_worst_slack -max -digits 6
report_net rst_n > $out/logs/rst_n_after_repair.rpt
catch {remove_fillers}
pg_connect
set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {2000 400}} m]} {
  puts "DPL_RETRY $m"
  detailed_placement -max_displacement {5000 800}
}
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
puts "CHECK_PLACEMENT_OK"
destroy_signal_wires
global_route -congestion_iterations 50 -verbose
puts "E_ANT_BEFORE DIODE [diode_count]"
check_antennas
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
puts "E_ANT_AFTER DIODE [diode_count]"
catch {detailed_placement -max_displacement {500 100}}
remove_pad_spacing_obs
write_db $out/rst_grt.odb
write_def $out/rst_grt.def
puts "WROTE_RST_GRT"
exit
