# SPEF-aware setup repair after ACH-shell route_fresh. Does not regenerate PDN.
# Incremental DRT only — do not destroy existing signal/PDN wires.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set pdk /foss/pdks/gf180mcuD
set src $out/filled.odb
puts "ECO_SRC $src"

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
proc protect_specials {} {
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    set m [[$inst getMaster] getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|cts)} $n]} { catch {set_dont_touch $n} }
    if {[string match "ach_tie_*" $n] || [string match "ach_rx_load_*" $n]} {
      catch {set_dont_touch $n}
    }
    if {[string match "*__antenna" $m]} {
      catch {set_dont_touch $n}
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

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
pg_connect
ensure_m2_obs
catch {remove_fillers}
pg_connect
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
# Extracted RC on the unfilled ACH-shell route; placement estimates hide the
# -4 ns setup that OpenRCX reports on this same netlist.
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
write_spef $out/spef/unfilled.max.spef
read_spef -corner $c $out/spef/unfilled.max.spef
protect_specials
apply_dont_use
puts "SETUP_BEFORE"
report_worst_slack -max -digits 6
report_tns -max -digits 6
puts "REPAIR_DESIGN"
if {[catch {repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20} m]} {
  puts "REPAIR_DESIGN_CAUGHT $m"
}
puts "REPAIR_TIMING_SETUP"
# Previous sizeup closed unfilled extract to +0.15 ns, then a full re-route
# lost ~3 ns on filled OpenRCX. Over-repair so the next route can absorb that.
if {[catch {
  repair_timing -setup -verbose -setup_margin 4.0 -repair_tns 100 \
    -max_buffer_percent 80 -max_utilization 90 -sequence sizeup
} m]} { puts "REPAIR_TIMING_SIZEUP_CAUGHT $m" }
puts "SETUP_AFTER_REPAIR"
report_worst_slack -max -digits 6
report_tns -max -digits 6
set_placement_padding -global -left 1 -right 1
foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap gf180mcu_fd_sc_mcu9t5v0__antenna} {
  catch {set_placement_padding -masters $wildcard -right 0 -left 0}
}
if {[catch {detailed_placement -max_displacement {2000 400}} m]} {
  puts "DPL_RETRY $m"
  detailed_placement -max_displacement {5000 800}
}
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
puts "CHECK_PLACEMENT_OK"
pg_connect
write_db $out/setup_pre_drt.odb
puts "WROTE_SETUP_PRE_DRT"
exit
