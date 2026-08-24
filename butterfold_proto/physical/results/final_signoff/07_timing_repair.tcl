# One bounded native recovery: repair remaining ordinary electrical, then
# extracted-aware repair_timing -setup (LibreLane rsz_timing_postgrt pattern).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/butterfold_top_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $c $out/spef/butterfold_top.max.spef

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

puts "T_BEFORE_INST $n_before"
puts "T_BEFORE_SETUP"
report_worst_slack -max -digits 6
puts "T_BEFORE_SLEW [sta::max_slew_violation_count]"
puts "T_BEFORE_CAP [sta::max_capacitance_violation_count]"

estimate_parasitics -placement
unset_case_analysis [get_ports rst_n]
puts "T_REPAIR_DESIGN"
repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
set_case_analysis 1 [get_ports rst_n]
puts "T_AFTER_DESIGN_SLEW [sta::max_slew_violation_count]"
puts "T_AFTER_DESIGN_CAP [sta::max_capacitance_violation_count]"

puts "T_REPAIR_TIMING_SETUP"
repair_timing -setup -verbose -setup_margin 0.1 -repair_tns 100
puts "T_AFTER_SETUP"
report_worst_slack -max -digits 6
report_tns -max -digits 6
report_worst_slack -min -digits 6

set n_after [llength [$block getInsts]]
puts "T_AFTER_INST $n_after DELTA [expr {$n_after-$n_before}]"
write_db $out/t_prelegal.odb

set_placement_padding -global -left 1 -right 1
foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
  catch {set_placement_padding -masters $wildcard -right 0 -left 0}
}
catch {remove_fillers}
detailed_placement -max_displacement {500 100}
if {[catch {check_placement -verbose} cmsg]} { puts "T_PLACE $cmsg"; exit 1 }
puts "T_CHECK_PLACEMENT_OK"
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
set die_mm2 [expr {double([$die dx]) * [$die dy] / ($dbu * $dbu) / 1e6}]
puts "T_DIE_MM2 $die_mm2"
if {$die_mm2 > 1.25} { puts DIE_AREA_FAIL; exit 1 }

foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
puts "T_GRT"
global_route -congestion_iterations 50 -verbose -guide_file $out/t.guide
puts "T_ANT_BEFORE"
check_antennas
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
puts "T_ANT_AFTER"
check_antennas
catch {detailed_placement -max_displacement {500 100}}
if {[catch {check_placement -verbose} cmsg]} { puts "T_PLACE_ANT $cmsg"; exit 1 }
write_db $out/t_grt_ant.odb
puts "T_PHASE1_DONE"
