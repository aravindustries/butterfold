# Read-only native reports from the final ECO routed ODB + matching SPEFs.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
set ev $proto/physical/reports/signoff/evidence
file mkdir $ev/setup
file mkdir $ev/hold
file mkdir $ev/electrical
file mkdir $ev/reset
file mkdir $ev/antenna
file mkdir $ev/area
file mkdir $ev/routing

puts "EVIDENCE_TOOL OpenROAD/OpenSTA 26Q2-254-g61932e897"
puts "EVIDENCE_ODB $out/butterfold_top_routed.odb"
puts "EVIDENCE_MAX_SPEF $out/spef/butterfold_top.max.spef"
puts "EVIDENCE_MIN_SPEF $out/spef/butterfold_top.min.spef"

set cmax max_ss_125C_4v50
set cmin min_ff_n40C_5v50
define_corners $cmax $cmin
read_liberty -corner $cmax /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $cmax /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_liberty -corner $cmin /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty -corner $cmin /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $out/butterfold_top_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $cmax $out/spef/butterfold_top.max.spef
read_spef -corner $cmin $out/spef/butterfold_top.min.spef

puts "EVIDENCE_CORNER_MAX $cmax"
puts "EVIDENCE_CORNER_MIN $cmin"
puts "EVIDENCE_PERIOD [get_property [lindex [all_clocks] 0] period]"

report_units
report_worst_slack -max -digits 6
report_tns -max -digits 6
report_worst_slack -min -digits 6
report_tns -min -digits 6

# Dedicated files via OpenSTA redirect
redirect $ev/setup/max_ss_setup_summary.rpt {
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
}
redirect $ev/setup/max_ss_worst_paths.rpt {
  report_checks -path_delay max -sort_by_slack -group_path_count 1 -endpoint_path_count 5 -digits 6
}
redirect $ev/hold/min_ff_hold_summary.rpt {
  report_worst_slack -min -digits 6
  report_tns -min -digits 6
}
redirect $ev/hold/min_ff_worst_paths.rpt {
  report_checks -path_delay min -sort_by_slack -group_path_count 1 -endpoint_path_count 5 -digits 6
}
redirect $ev/electrical/max_slew.rpt {
  report_check_types -max_slew -violators -digits 4
}
redirect $ev/electrical/max_cap.rpt {
  report_check_types -max_capacitance -violators -digits 4
}
if {[catch {redirect $ev/electrical/fanout.rpt { report_check_types -max_fanout -violators -digits 4 }} ferr]} {
  puts "FANOUT_REPORT_CATCH $ferr"
}

puts "CASE_ON_SLEW [sta::max_slew_violation_count]"
puts "CASE_ON_CAP [sta::max_capacitance_violation_count]"

unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
redirect $ev/reset/reset_electrical.rpt {
  report_check_types -max_slew -max_capacitance -violators -digits 4
}
redirect $ev/reset/reset_topology.rpt {
  report_net rst_n
}
set_case_analysis 1 [get_ports rst_n]

report_checks -path_delay max -sort_by_slack -group_path_count 1 -endpoint_path_count 1 -digits 6
redirect $ev/power/vectorless_power.rpt {
  report_power -corner $cmax -digits 6
}

# Area / inventory
set block [ord::get_db_block]
set die [$block getDieArea]
set core [$block getCoreArea]
set insts [$block getInsts]
set n_inst [llength $insts]
set n_sram 0
set n_diode 0
set n_fill 0
foreach inst $insts {
  set m [[$inst getMaster] getName]
  if {[string match "*sram256x8*" $m]} { incr n_sram }
  if {[string match "*__antenna" $m]} { incr n_diode }
  if {[string match "*__fill_*" $m] || [string match "*fillcap*" $m] || [string match "*filltie*" $m] || [string match "*endcap*" $m]} { incr n_fill }
}
set dbu [[[ord::get_db] getTech] getDbUnitsPerMicron]
set dx [expr {([$die xMax] - [$die xMin]) / double($dbu)}]
set dy [expr {([$die yMax] - [$die yMin]) / double($dbu)}]
set area_mm2 [expr {$dx * $dy / 1e6}]
set fout [open $ev/area/final_area.rpt w]
puts $fout "OpenROAD area report (read-only)"
puts $fout "die_um $dx $dy"
puts $fout "die_mm2 $area_mm2"
puts $fout "die_bbox [$die xMin] [$die yMin] [$die xMax] [$die yMax]"
puts $fout "core_bbox [$core xMin] [$core yMin] [$core xMax] [$core yMax]"
puts $fout "dbu $dbu"
close $fout
set fout [open $ev/area/final_inventory.rpt w]
puts $fout "OpenROAD inventory (read-only)"
puts $fout "instances $n_inst"
puts $fout "sram $n_sram"
puts $fout "antenna_diodes $n_diode"
puts $fout "fill_like $n_fill"
puts $fout "nets [llength [$block getNets]]"
close $fout

set fout [open $ev/antenna/diode_inventory.rpt w]
puts $fout "OpenROAD antenna diode inventory"
puts $fout "count $n_diode"
foreach inst $insts {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    puts $fout "[$inst getName] $m"
  }
}
close $fout

check_antennas
puts "ANTENNA_DONE"

report_design_area
puts "EVIDENCE_DUMP_DONE"
