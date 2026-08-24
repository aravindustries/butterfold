# Native repair_antennas diode-only on GRT (LibreLane OpenROAD.RepairAntennas)
set out /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff
read_db $out/butterfold_top_grt.odb
set block [ord::get_db_block]
set d0 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d0 }
}
puts "DIODE_BEFORE $d0"
check_antennas
puts "REPAIR_DIODE_ONLY"
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 5 -ratio_margin 20 -diode_only
set d1 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d1 }
}
puts "DIODE_AFTER $d1"
check_antennas
write_db $out/butterfold_top_grt_diodes.odb
puts "WROTE_GRT_DIODES"
