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
set n0 [llength [$block getInsts]]
foreach inst [$block getInsts] {
  set n [$inst getName]
  set m [[$inst getMaster] getName]
  if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { set_dont_touch $n }
  if {[string match "*__antenna" $m]} { set_dont_touch $n; $inst setPlacementStatus FIRM }
  if {[string match "*sram256x8*" $m]} { set_dont_touch $n }
}
puts "R2_BEFORE_SLEW [sta::max_slew_violation_count]"
puts "R2_BEFORE_CAP [sta::max_capacitance_violation_count]"
puts "R2_BEFORE_INST $n0"
repair_design -verbose -max_wire_length 0 -slew_margin 10 -cap_margin 10
set n1 [llength [$block getInsts]]
puts "R2_AFTER_SLEW [sta::max_slew_violation_count]"
puts "R2_AFTER_CAP [sta::max_capacitance_violation_count]"
puts "R2_AFTER_INST $n1"
puts "R2_DELTA [expr {$n1-$n0}]"
write_db $out/r2_prelegal.odb
puts WROTE_R2
