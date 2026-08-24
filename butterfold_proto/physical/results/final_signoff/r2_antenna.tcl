set out /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff
read_db $out/r2_grt.odb
set block [ord::get_db_block]
set d0 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d0 }
}
puts "DIODE_BEFORE $d0"
check_antennas
puts "REPAIR"
# jumpers + diodes, extra margin for DRT survival
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 5 -ratio_margin 30
set d1 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr d1 }
}
puts "DIODE_AFTER $d1"
check_antennas
write_db $out/r2_grt_ant.odb
puts WROTE
