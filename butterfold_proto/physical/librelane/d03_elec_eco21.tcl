# In-place _1->_2 on remaining slew/cap drivers. Re-extract, no re-route if legal.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_ant20b.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set db [ord::get_db]
set block [ord::get_db_block]
foreach {inst tgt} {
  _12379_ gf180mcu_fd_sc_mcu9t5v0__aoi22_2
  _12380_ gf180mcu_fd_sc_mcu9t5v0__oai31_2
  _11319_ gf180mcu_fd_sc_mcu9t5v0__aoi21_2
} {
  set i [$block findInst $inst]
  set m [$db findMaster $tgt]
  if {$i eq "NULL" || $m eq "NULL"} { puts "NO $inst"; continue }
  if {[catch {$i swapMaster $m} msg]} { puts "FAIL $inst $msg" } else { puts "SWAP $inst $tgt" }
}
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }
foreach n {_12379_ _12380_ _11319_} {
  set i [$block findInst $n]
  if {$i ne "NULL"} { $i setPlacementStatus PLACED }
}
set_placement_padding -global -left 2 -right 2
catch {detailed_placement -max_displacement {200 40}}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg" } else { puts "PLACE_OK" }
write_db $eco/butterfold_top_elec21.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/elec21.max.spef
read_spef $eco/elec21.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/elec21_electrical.rpt}
catch {report_wns -max > $out/elec21_wns.rpt}
puts "ELEC21_COMPLETE"
exit
