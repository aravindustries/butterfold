# ECO18e: manually place capture clkbuf in a legal hole (no neighbor
# movement), FIRM everything, incremental route only.
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
set ff [$block findInst _18433_]
lassign [$ff getLocation] fx fy
puts "FF $fx $fy w=[[$c16 getWidth]] h=[[$c16 getHeight]]"

foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set clk [$ff findITerm CLK]
set n [$clk getNet]
set buf [odb::dbInst_create $block $c16 eco18_sk_18433]
$buf setOrient R0
$buf setPlacementStatus PLACED

# Search a grid of candidate sites below/left of the FF.
set site 1120
set row 10080
set placed 0
foreach dy { -2 -3 -4 -5 -6 -1 1 2 -8 -10 } {
  foreach dx { -40 -30 -20 -10 -50 10 20 -60 0 } {
    set x [expr {$fx + $dx * $site}]
    set y [expr {$fy + $dy * $row}]
    $buf setLocation $x $y
    if {![catch {check_placement} ]} {
      puts "LEGAL_LOC $x $y dx=$dx dy=$dy"
      set placed 1
      break
    }
  }
  if {$placed} { break }
}
if {!$placed} {
  puts "NO_LEGAL_LOC using fallback"
  $buf setLocation [expr {$fx - 80*$site}] [expr {$fy - 8*$row}]
}
$buf setPlacementStatus FIRM
set n2 [odb::dbNet_create $block eco18_net_18433]
odb::dbITerm_connect [$buf findITerm I] $n
odb::dbITerm_connect [$buf findITerm Z] $n2
odb::dbITerm_disconnect $clk
odb::dbITerm_connect $clk $n2
lassign [$buf getLocation] bx by
puts "BUF $bx $by"
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO18E_INCREMENTAL"
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
catch {global_route -start_incremental}
catch {global_route -end_incremental}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/eco18e.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
set n2b [$block findNet eco18_net_18433]
puts "NEW_NET_WIRE [$n2b getWire]"
write_db $eco/butterfold_top_eco18e.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco18e.max.spef
  read_spef $eco/eco18e.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO18E_EXTRACTED_WNS"
report_wns -max
report_tns -max
report_checks -path_delay max -group_path_count 3
if {[catch {check_placement -verbose} m2]} { puts "PLACE2 $m2" } else { puts "PLACE2_OK" }
catch {report_wns -max > $out/eco18e_spef_wns.rpt}
catch {report_tns -max > $out/eco18e_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 10 > $out/eco18e_spef_violations.rpt}
puts "ECO18E_COMPLETE"
exit
