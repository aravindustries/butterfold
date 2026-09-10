set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
read_db $out/ach_ant_via.odb
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
set ant [check_antennas]
puts "ANT $ant"
if {$ant} {
  check_antennas -verbose -report_file $out/antenna/post_via.rpt
}
write_db $out/ach_ant_routed.odb
write_def $out/ach_ant_routed.def
puts "WROTE_ACH_ANT_ROUTED"
exit
