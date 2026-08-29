# ECO18h: place capture clkbuf_16 in a known-legal hole at the bottom
# of the core (site-snapped). FIRM everything. Incremental GRT/DRT.
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
set buf [odb::dbInst_create $block $c16 eco18_sk_18433]
$buf setOrient R0
$buf setLocation 22400 50400
$buf setPlacementStatus FIRM
set n2 [odb::dbNet_create $block eco18_net_18433]
odb::dbITerm_connect [$buf findITerm I] $n
odb::dbITerm_connect [$buf findITerm Z] $n2
odb::dbITerm_disconnect $clk
odb::dbITerm_connect $clk $n2
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO18I_FULL_GRT_KEEP_WIRES"
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
# Full GRT to generate a guide for the new net; do not destroy existing wires.
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/eco18i.guide} gmsg]} {
  puts "GRT_WARN $gmsg"
}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/eco18i.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
set n2b [$block findNet eco18_net_18433]
puts "NEW_NET_WIRE [$n2b getWire]"
write_db $eco/butterfold_top_eco18i.odb
write_def $eco/butterfold_top_eco18i.def
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco18i.max.spef
  read_spef $eco/eco18i.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO18I_EXTRACTED_WNS"
report_wns -max
report_tns -max
report_checks -path_delay max -group_path_count 5
if {[catch {check_placement -verbose} m2]} { puts "PLACE2 $m2" } else { puts "PLACE2_OK" }
catch {report_wns -max > $out/eco18i_spef_wns.rpt}
catch {report_tns -max > $out/eco18i_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 10 > $out/eco18i_spef_violations.rpt}
puts "ECO18I_COMPLETE"
exit
