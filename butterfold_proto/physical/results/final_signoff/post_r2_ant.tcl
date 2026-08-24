read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
check_antennas
set block [ord::get_db_block]
set d 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d }
}
puts "DIODE_FINAL $d"
