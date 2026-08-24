# Native OpenROAD check_antennas + repair_antennas (LibreLane OpenROAD.RepairAntennas)
set out /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff
read_db $out/butterfold_top_grt.odb
set block [ord::get_db_block]
set d0 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d0 }
}
puts "DIODE_BEFORE $d0"
puts "ANTENNA_CHECK_PRE"
check_antennas -verbose
puts "ANTENNA_REPAIR_BEGIN"
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
puts "ANTENNA_REPAIR_DONE"
set d1 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d1 }
}
puts "DIODE_AFTER $d1"
puts "ANTENNA_CHECK_POST"
check_antennas -verbose
write_db $out/butterfold_top_grt_antenna.odb
write_def $out/butterfold_top_grt_antenna.def
puts "WROTE_ANTENNA_GRT"
