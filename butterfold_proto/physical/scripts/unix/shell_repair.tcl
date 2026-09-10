# Extracted-aware setup + hold repair on the shelled build.
set cmax max_ss_125C_4v50
set cmin min_ff_n40C_5v50
define_corners $cmax $cmin
read_liberty -corner $cmax $::env(LIB_STD_SS)
read_liberty -corner $cmax $::env(LIB_SRAM_SS)
read_liberty -corner $cmin $::env(LIB_STD_FF)
read_liberty -corner $cmin $::env(LIB_SRAM_FF)
read_db $::env(IN_ODB)
read_sdc $::env(SDC)
# the ACH shell renames the ten outputs; constrain the post-shell names
catch {set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]}
set_propagated_clock [all_clocks]
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $cmax $::env(ITER_DIR)/spef/butterfold_top.max.spef
read_spef -corner $cmin $::env(ITER_DIR)/spef/butterfold_top.min.spef

set block [ord::get_db_block]
set n0 [llength [$block getInsts]]
foreach inst [$block getInsts] {
  set n [$inst getName]; set m [[$inst getMaster] getName]
  if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { set_dont_touch $n }
  # antenna diodes are NOT dont_touch: that blocks repair_design buffering
  # (RSZ-3006), and the reroute step re-runs repair_antennas anyway.
  if {[string match "*__antenna" $m]} { $inst setPlacementStatus PLACED }
  if {[string match "*sram256x8*" $m]} { set_dont_touch $n }
  if {[string match "ach_*" $n]} { set_dont_touch $n }
}
puts "X_IN_INST $n0"
puts "X_IN_SETUP"; report_worst_slack -max -digits 6
puts "X_IN_HOLD";  report_worst_slack -min -digits 6

repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
puts "X_MID_SETUP"; report_worst_slack -max -digits 6

set smargin 1.50
if {[info exists ::env(SETUP_MARGIN)] && $::env(SETUP_MARGIN) ne ""} { set smargin $::env(SETUP_MARGIN) }
puts "X_SETUP_MARGIN $smargin"
repair_timing -setup -verbose -setup_margin $smargin -repair_tns 100
puts "X_POST_SETUP"; report_worst_slack -max -digits 6
puts "X_POST_SETUP_TNS"; report_tns -max -digits 6

repair_timing -hold -verbose -hold_margin 0.05 -allow_setup_violations
puts "X_POST_HOLD_SETUP"; report_worst_slack -max -digits 6
puts "X_POST_HOLD";       report_worst_slack -min -digits 6
puts "X_SLEW [sta::max_slew_violation_count]  X_CAP [sta::max_capacitance_violation_count]"
puts "X_OUT_INST [llength [$block getInsts]] DELTA [expr {[llength [$block getInsts]]-$n0}]"

# no global padding -- it makes check_placement fail on cells that were legal
catch {remove_fillers}
detailed_placement -max_displacement {500 100}
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
write_db $::env(ITER_DIR)/setup_closed.odb
puts "X_WROTE setup_closed.odb"
if {[catch {check_placement -verbose} m]} { puts "X_PLACE_WARN $m" } else { puts "X_PLACE_OK" }
