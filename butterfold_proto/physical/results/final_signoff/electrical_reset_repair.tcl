# Native OpenROAD repair_design on extracted max-SS parasitics.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
file mkdir $out
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

set exclude_file /foss/pdks/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
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

puts "BEFORE_SLEW [sta::max_slew_violation_count]"
puts "BEFORE_CAP [sta::max_capacitance_violation_count]"
puts "BEFORE_INST $n_before"

puts "UNSET_CASE_ANALYSIS rst_n for electrical repair only"
unset_case_analysis [get_ports rst_n]
puts "AFTER_UNSET_SLEW [sta::max_slew_violation_count]"
puts "AFTER_UNSET_CAP [sta::max_capacitance_violation_count]"

puts "REPAIR_DESIGN_BEGIN"
set t0 [clock milliseconds]
repair_design -verbose -max_wire_length 0 -slew_margin 10 -cap_margin 10
puts "REPAIR_DESIGN_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"

set n_after [llength [$block getInsts]]
puts "AFTER_REPAIR_SLEW [sta::max_slew_violation_count]"
puts "AFTER_REPAIR_CAP [sta::max_capacitance_violation_count]"
puts "AFTER_INST $n_after"
puts "INST_DELTA [expr {$n_after - $n_before}]"
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 > $out/electrical_after_repair_reset_visible.rpt

set_case_analysis 1 [get_ports rst_n]
puts "RESTORED_CASE_ANALYSIS"
puts "RESTORED_SLEW [sta::max_slew_violation_count]"
puts "RESTORED_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 > $out/electrical_after_repair_case_restored.rpt

write_db $out/butterfold_top_elec_prelegal.odb
write_def $out/butterfold_top_elec_prelegal.def
puts "WROTE_PRELEGAL"
