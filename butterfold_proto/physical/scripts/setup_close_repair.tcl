# Extracted-aware setup closure, generic version of the recorded
# postroute_setup_close.tcl.  Do NOT estimate_parasitics here: that would
# overwrite the SPEF and hide the real extracted fail.
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $::env(LIB_STD)
read_liberty -corner $c $::env(LIB_SRAM)
read_db $::env(IN_ODB)
read_sdc $::env(SDC)
set_propagated_clock [all_clocks]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $c $::env(OUT_DIR)/spef/butterfold_top.max.spef

set block [ord::get_db_block]
set n_before [llength [$block getInsts]]
foreach inst [$block getInsts] {
  set n [$inst getName]
  set m [[$inst getMaster] getName]
  if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { set_dont_touch $n }
  if {[string match "*__antenna" $m]} { set_dont_touch $n; $inst setPlacementStatus FIRM }
  if {[string match "*sram256x8*" $m]} { set_dont_touch $n }
}

puts "X_BEFORE_INST $n_before"
puts "X_BEFORE_WNS"; report_worst_slack -max -digits 6
puts "X_BEFORE_SLEW [sta::max_slew_violation_count]"
puts "X_BEFORE_CAP  [sta::max_capacitance_violation_count]"

puts "X_REPAIR_DESIGN"
repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
report_worst_slack -max -digits 6

puts "X_REPAIR_TIMING_SETUP"
repair_timing -setup -verbose -setup_margin 0.1 -repair_tns 100
puts "X_AFTER_WNS"; report_worst_slack -max -digits 6
puts "X_AFTER_TNS"; report_tns -max -digits 6
puts "X_AFTER_HOLD"; report_worst_slack -min -digits 6
puts "X_AFTER_SLEW [sta::max_slew_violation_count]"
puts "X_AFTER_CAP  [sta::max_capacitance_violation_count]"
set n_after [llength [$block getInsts]]
puts "X_AFTER_INST $n_after DELTA [expr {$n_after-$n_before}]"

set_placement_padding -global -left 1 -right 1
foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
  catch {set_placement_padding -masters $wildcard -right 0 -left 0}
}
catch {remove_fillers}
detailed_placement -max_displacement {500 100}
if {[catch {check_placement -verbose} cmsg]} { puts "X_PLACE_FAIL $cmsg"; exit 1 }
puts "X_CHECK_PLACEMENT_OK"

add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect

write_db  $::env(OUT_DIR)/setup_closed.odb
write_def $::env(OUT_DIR)/setup_closed.def
puts "X_WROTE $::env(OUT_DIR)/setup_closed.odb"
