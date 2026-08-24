# Native OpenROAD electrical + reset repair, legalize, clear signal routes, GRT,
# GRT-level antenna repair. Mirrors LibreLane repair_design / dpl / grt /
# antenna_repair without restarting P&R.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
file mkdir $out
file mkdir $out/antenna

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $proto/physical/results/38p4_setup_closed/iter2_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $c $proto/physical/results/38p4_setup_closed/spef/butterfold_top.max.spef

set block [ord::get_db_block]
set n_before [llength [$block getInsts]]
foreach inst [$block getInsts] {
  set n [$inst getName]
  set m [[$inst getMaster] getName]
  if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { set_dont_touch $n }
  if {[string match "*__antenna" $m]} {
    set_dont_touch $n
    $inst setPlacementStatus FIRM
  }
  if {[string match "*sram256x8*" $m]} { set_dont_touch $n }
}

puts "BEFORE_INST $n_before"
puts "BEFORE_SLEW [sta::max_slew_violation_count]"
puts "BEFORE_CAP [sta::max_capacitance_violation_count]"

puts "UNSET_CASE_ANALYSIS rst_n for electrical repair only"
unset_case_analysis [get_ports rst_n]
puts "AFTER_UNSET_SLEW [sta::max_slew_violation_count]"
puts "AFTER_UNSET_CAP [sta::max_capacitance_violation_count]"

# LibreLane DESIGN_REPAIR_MAX_SLEW_PCT / MAX_CAP_PCT default is 20.
puts "REPAIR_DESIGN_BEGIN"
set t0 [clock milliseconds]
repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
puts "REPAIR_DESIGN_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"

set n_after [llength [$block getInsts]]
puts "AFTER_REPAIR_SLEW [sta::max_slew_violation_count]"
puts "AFTER_REPAIR_CAP [sta::max_capacitance_violation_count]"
puts "AFTER_INST $n_after"
puts "INST_DELTA [expr {$n_after - $n_before}]"
report_net rst_n > $out/reset_after_repair.rpt

set_case_analysis 1 [get_ports rst_n]
puts "RESTORED_CASE_ANALYSIS"
puts "RESTORED_SLEW [sta::max_slew_violation_count]"
puts "RESTORED_CAP [sta::max_capacitance_violation_count]"

write_db $out/butterfold_top_elec_prelegal.odb
puts "WROTE_PRELEGAL"

# LibreLane dpl.tcl: padding, remove fillers, detailed_placement, check_placement
set_placement_padding -global -left 1 -right 1
foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
  catch {set_placement_padding -masters $wildcard -right 0 -left 0}
}
puts "REMOVE_FILLERS"
catch {remove_fillers}

puts "LEGALIZE_BEGIN"
set t0 [clock milliseconds]
detailed_placement -max_displacement {500 100}
puts "LEGAL_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"
if {[catch {check_placement -verbose} cmsg]} {
  puts "CHECK_PLACEMENT $cmsg"
  exit 1
} else {
  puts "CHECK_PLACEMENT_OK"
}

# Re-connect power pins on newly inserted cells (LibreLane set_global_connections)
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "GLOBAL_CONNECT_DONE"

# Unlock diodes for later legalize of antenna repair
foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    catch {unset_dont_touch [$inst getName]}
    $inst setPlacementStatus PLACED
  }
}

set die [$block getDieArea]
set tech [ord::get_db_tech]
set dbu [$tech getDbUnitsPerMicron]
set die_mm2 [expr {double([$die dx]) * [$die dy] / ($dbu * $dbu) / 1e6}]
puts "DIE_MM2 $die_mm2"
if {$die_mm2 > 1.25} {
  puts "DIE_AREA_FAIL"
  exit 1
}

write_db $out/butterfold_top_elec_legal.odb
write_def $out/butterfold_top_elec_legal.def
puts "WROTE_LEGAL"

# Clear ordinary signal wires + guides; keep PDN special nets and NDR objects.
set dw 0
set gd 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} {
    catch {odb::dbWire_destroy $w}
    incr dw
  }
  catch {
    set nguid [llength [$net getGuides]]
    if {$nguid > 0} {
      $net clearGuides
      incr gd $nguid
    }
  }
}
puts "CLEARED_WIRES $dw GUIDES $gd"

write_db $out/butterfold_top_clean_unrouted.odb
puts "WROTE_CLEAN"

# Native GRT (LibreLane grt.tcl pattern: Metal2-Metal5, 30% adjustment, 50 iters)
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
puts "GRT_BEGIN"
set t0 [clock milliseconds]
global_route -congestion_iterations 50 -verbose -guide_file $out/butterfold_top.guide
puts "GRT_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"
write_db $out/butterfold_top_grt.odb
puts "WROTE_GRT"

puts "ANTENNA_GRT_BEFORE"
check_antennas
set diode_n 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr diode_n }
}
puts "DIODE_BEFORE $diode_n"

# LibreLane antenna_repair.tcl
puts "REPAIR_ANTENNAS_GRT"
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
puts "ANTENNA_GRT_AFTER"
check_antennas
set diode_n 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr diode_n }
}
puts "DIODE_AFTER_GRT $diode_n"

# Legalize any inserted diodes (LibreLane RepairAntennas does DPL)
catch {detailed_placement -max_displacement {500 100}}
if {[catch {check_placement -verbose} cmsg]} {
  puts "CHECK_PLACEMENT_ANT $cmsg"
  exit 1
}
puts "CHECK_PLACEMENT_ANT_OK"
write_db $out/butterfold_top_grt_antenna.odb
puts "WROTE_GRT_ANTENNA"
puts "PHASE1_DONE"
