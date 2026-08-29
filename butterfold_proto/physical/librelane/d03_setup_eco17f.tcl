# ECO17f: incremental GRT (-start_incremental) from eco16b.
# nor3_1 SRAM GWEN + extra _18433_ capture buf. Do not destroy wires.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco16b_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
set inv8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkinv_8]
set n3 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__nor3_4]
set i [$block findInst _09881_]
if {$i ne "NULL" && $n3 ne "NULL"} { catch {$i swapMaster $n3}; puts "SWAP _09881_" }
foreach name {
  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_gwen_driver
  u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_gwen_driver
} {
  set j [$block findInst $name]
  if {$j ne "NULL" && $j ne "" && $inv8 ne "NULL"} { catch {$j swapMaster $inv8}; puts "SWAP $name" }
}

set ff [$block findInst _18433_]
set clk [$ff findITerm CLK]
set n [$clk getNet]
set buf [odb::dbInst_create $block $c16 eco17_sk_18433]
lassign [$ff getLocation] x y
$buf setOrient R0
$buf setLocation [expr {$x + 2240}] [expr {$y + 5040}]
$buf setPlacementStatus PLACED
set n2 [odb::dbNet_create $block eco17_net_18433]
odb::dbITerm_connect [$buf findITerm I] $n
odb::dbITerm_connect [$buf findITerm Z] $n2
odb::dbITerm_disconnect $clk
odb::dbITerm_connect $clk $n2
puts "SKEW _18433_"

foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match "*dff*" $mn] || [string match "*sram*" $mn]} {
    $inst setPlacementStatus FIRM
  }
}
set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} { puts "LEGALIZE_WARN $msg" }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO17F_INCREMENTAL"
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
catch {global_connect}
if {[catch {global_route -start_incremental} g1]} { puts "GRT_START $g1" }
if {[catch {global_route -end_incremental} g2]} { puts "GRT_END $g2" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/eco17f.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
}
write_db $eco/butterfold_top_eco17f_routed.odb
write_def $eco/butterfold_top_eco17f_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco17f.max.spef
  read_spef $eco/eco17f.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO17F_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco17f_spef_wns.rpt}
catch {report_tns -max > $out/eco17f_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 20 > $out/eco17f_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco17f_spef_electrical.rpt}
puts "ECO17F_COMPLETE"
exit
