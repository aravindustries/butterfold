# Dump remaining antenna violations from ach_ant_routed.odb.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
file mkdir $out/antenna
read_db $out/ach_ant_routed.odb
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
set n 0
foreach inst [[ord::get_db_block] getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
}
puts "DIODE $n"
set ant [check_antennas -verbose -report_file $out/antenna/remaining.rpt]
puts "ANT $ant"
exit
