# Native inventory + reset-visible electrical dump for signoff reports.
# Does not modify the ODB.

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
read_sdc /headless/aravindustries-repos/butterfold/butterfold_proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
read_spef -corner $c /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/spef/butterfold_top.max.spef

set block [ord::get_db_block]
set tech [ord::get_db_tech]
set dbu [$tech getDbUnitsPerMicron]
puts "DBU $dbu"
set die [$block getDieArea]
puts "DIE_BOUNDS [$die xMin] [$die yMin] [$die xMax] [$die yMax]"
puts "DIE_UM2 [expr {double([$die dx]) * [$die dy] / ($dbu * $dbu)}]"
set core [$block getCoreArea]
puts "CORE_BOUNDS [$core xMin] [$core yMin] [$core xMax] [$core yMax]"
puts "CORE_UM2 [expr {double([$core dx]) * [$core dy] / ($dbu * $dbu)}]"

set insts [$block getInsts]
puts "INST [llength $insts]"
set diodes 0
set sram 0
set fill 0
set inst_area 0.0
foreach inst $insts {
  set master [$inst getMaster]
  set m [$master getName]
  set inst_area [expr {$inst_area + double([$master getWidth]) * [$master getHeight] / ($dbu * $dbu)}]
  if {[string match "*antenna*" $m]} { incr diodes }
  if {[string match "*sram256x8*" $m]} { incr sram }
  if {[string match "*fill*" $m] || [string match "*FILL*" $m]} { incr fill }
}
puts "DIODE $diodes"
puts "SRAM $sram"
puts "FILL $fill"
puts "INST_AREA_UM2 $inst_area"

set nets [$block getNets]
set sig 0
set pace 0
foreach n $nets {
  if {[$n getSigType] eq "SIGNAL"} { incr sig }
  if {[string match "*pace_count*" [$n getName]]} { incr pace }
}
puts "SIGNAL_NETS $sig"
puts "PACE_NETS $pace"

puts "==== CASE_ON ELECTRICAL ===="
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"

puts "==== CLOCK ===="
report_net clk

puts "==== UNSET rst_n CASE FOR ELECTRICAL ONLY ===="
unset_case_analysis rst_n
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators -digits 4 > /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/sta_max_ss/electrical_reset_visible.rpt
report_net rst_n
report_net net246
report_net net247
report_net net248

set_case_analysis 1 [get_ports rst_n]
puts "RESTORED_CASE"
puts "DONE"
