# Antenna repair on hold19c (setup+hold closed). Keep sequential FIRM.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_hold19c.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
# cap: try aoi21_1 -> 4 in place
set i [$block findInst _11319_]
if {$i ne "NULL" && $i ne ""} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi21_4]
  if {$m ne "NULL"} {
    if {[catch {$i swapMaster $m} msg]} { puts "CAP_SWAP_FAIL $msg" } else { puts "CAP_SWAP aoi21_4" }
  }
}
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match "*dff*" $mn] || [string match "*sram*" $mn]} { $inst setPlacementStatus FIRM }
}
set_placement_padding -global -left 2 -right 2
catch {detailed_placement -max_displacement {200 40}}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg" } else { puts "PLACE_OK" }

puts "ANTENNA_REPAIR"
if {[catch {repair_antennas -iterations 3} amsg]} { puts "REPAIR_ANT $amsg" }
puts "ANTENNA_DRT"
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/ant20.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
if {[catch {check_antennas -report_file $out/ant20.rpt} amsg2]} { puts "ANT_CHECK $amsg2" }
write_db $eco/butterfold_top_ant20.odb
write_def $eco/butterfold_top_ant20.def
puts "ANT20_COMPLETE"
exit
