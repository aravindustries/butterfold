# ECO18c from eco18b: all cells FIRM except one new capture clkbuf on
# _18433_. Incremental GRT/DRT. Close the last 80 ps.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco18b.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]

foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set ff [$block findInst _18433_]
set clk [$ff findITerm CLK]
set n [$clk getNet]
puts "CLKNET [$n getName]"
set buf [odb::dbInst_create $block $c16 eco18_sk_18433]
lassign [$ff getLocation] x y
# site 0.56 um = 1120 dbu at 2000 dbu/um; row 5.04 um = 10080 dbu
$buf setOrient R0
$buf setLocation [expr {$x + 1120*4}] [expr {$y + 10080}]
$buf setPlacementStatus PLACED
set n2 [odb::dbNet_create $block eco18_net_18433]
odb::dbITerm_connect [$buf findITerm I] $n
odb::dbITerm_connect [$buf findITerm Z] $n2
odb::dbITerm_disconnect $clk
odb::dbITerm_connect $clk $n2
puts "SKEW _18433_ inserted"

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {200 40}} msg]} { puts "LEGALIZE_WARN $msg" }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO18C_INCREMENTAL"
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
catch {global_route -start_incremental}
catch {global_route -end_incremental}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/eco18c.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else {
  puts "DRT_OK"
}
write_db $eco/butterfold_top_eco18c.odb
write_def $eco/butterfold_top_eco18c.def
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco18c.max.spef
  read_spef $eco/eco18c.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO18C_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco18c_spef_wns.rpt}
catch {report_tns -max > $out/eco18c_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 10 > $out/eco18c_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco18c_spef_electrical.rpt}
puts "ECO18C_COMPLETE"
exit
