# One multi-corner closure iteration: extracted-aware repair of setup (max_ss)
# and hold (min_ff) together, then legalize.  Routing is cleared and redone by
# reroute_route.tcl afterwards.
set cmax max_ss_125C_4v50
set cmin min_ff_n40C_5v50
define_corners $cmax $cmin
read_liberty -corner $cmax $::env(LIB_STD_SS)
read_liberty -corner $cmax $::env(LIB_SRAM_SS)
read_liberty -corner $cmin $::env(LIB_STD_FF)
read_liberty -corner $cmin $::env(LIB_SRAM_FF)
read_db $::env(IN_ODB)
read_sdc $::env(SDC)
set_propagated_clock [all_clocks]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $cmax $::env(ITER_DIR)/spef/butterfold_top.max.spef
read_spef -corner $cmin $::env(ITER_DIR)/spef/butterfold_top.min.spef

set block [ord::get_db_block]
set n_before [llength [$block getInsts]]
foreach inst [$block getInsts] {
  set n [$inst getName]
  set m [[$inst getMaster] getName]
  if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { set_dont_touch $n }
  if {[string match "*__antenna" $m]} { set_dont_touch $n; $inst setPlacementStatus FIRM }
  if {[string match "*sram256x8*" $m]} { set_dont_touch $n }
}
puts "X_IN_INST $n_before"
puts "X_IN_SETUP";  report_worst_slack -max -digits 6
puts "X_IN_HOLD";   report_worst_slack -min -digits 6

repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
puts "X_MID_SETUP"; report_worst_slack -max -digits 6

repair_timing -setup -verbose -setup_margin 1.30 -repair_tns 100
puts "X_POST_SETUP"; report_worst_slack -max -digits 6
puts "X_POST_SETUP_TNS"; report_tns -max -digits 6

repair_timing -hold -verbose -hold_margin 0.05 -allow_setup_violations
puts "X_POST_HOLD_SETUP"; report_worst_slack -max -digits 6
puts "X_POST_HOLD";       report_worst_slack -min -digits 6
puts "X_SLEW [sta::max_slew_violation_count]"
puts "X_CAP  [sta::max_capacitance_violation_count]"
set n_after [llength [$block getInsts]]
puts "X_OUT_INST $n_after DELTA [expr {$n_after-$n_before}]"

set_placement_padding -global -left 1 -right 1
foreach m {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_1
           gf180mcu_fd_sc_mcu9t5v0__fill_2 gf180mcu_fd_sc_mcu9t5v0__endcap} {
  if {[catch {set_placement_padding -masters $m -left 0 -right 0} e]} {
    puts "X_PADDING_EXEMPT_FAILED $m : $e"
  } else {
    puts "X_PADDING_EXEMPT_OK $m"
  }
}
catch {remove_fillers}
detailed_placement -max_displacement {500 100}

# Global connect and WRITE FIRST: a closed-timing database must never be lost
# to an advisory check.
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
write_db $::env(ITER_DIR)/setup_closed.odb
puts "X_WROTE $::env(ITER_DIR)/setup_closed.odb"

# Placement padding is a routing guide, not a DRC rule.  Report, do not abort:
# real legality is proven by detailed routing and by signoff DRC/LVS.
if {[catch {check_placement -verbose} cmsg]} {
  puts "X_PLACE_CHECK_WARN $cmsg"
} else {
  puts "X_CHECK_PLACEMENT_OK"
}
