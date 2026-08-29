# Hold ECO26 from hold25: swap hold_dlya_din0 dlya_4 -> dlyb_4.
# Need +80 ps on din[0]->_18681_. Extra 2 sites at 45920/47040 are FREE.
# din[0] max-SS slack is +15.38 ns. Rip only the two dlya nets. Keep wires.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_hold25.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set db [ord::get_db]
set block [ord::get_db_block]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set dlyb [$db findMaster gf180mcu_fd_sc_mcu9t5v0__dlyb_4]
set i [$block findInst hold_dlya_din0]
if {$i eq "NULL" || $dlyb eq "NULL"} { puts "MISSING_DLYA"; exit 1 }
if {[catch {$i swapMaster $dlyb} msg]} { puts "SWAP_FAIL $msg"; exit 1 }
$i setPlacementStatus FIRM
lassign [$i getLocation] x y
puts "SWAP hold_dlya_din0 [[$i getMaster] getName] $x $y w=[[$i getMaster] getWidth] orient=[$i getOrient]"

foreach t [$i getITerms] {
  set pn [[$t getMTerm] getName]
  if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
  set n [$t getNet]
  if {$n eq "NULL"} continue
  if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
  catch {$n clearGuides}
  puts "RIP [$n getName]"
}

catch {global_connect}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg" } else { puts "PLACE_OK" }

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/hold26.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/hold26.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_hold26.odb

puts "ANT"
catch {check_antennas}
puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/hold26.max.spef
read_spef $eco/hold26.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
catch {report_wns -max > $out/hold26_setup_wns.rpt}
catch {report_tns -max > $out/hold26_setup_tns.rpt}
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/hold26_electrical.rpt}
puts "HOLD26_COMPLETE"
exit
