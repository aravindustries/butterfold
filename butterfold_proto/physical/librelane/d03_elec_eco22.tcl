# Insert clkbuf_8 immediately after _12379_ (long _06907_ net) and
# clkbuf_8 after _11319_. Un-FIRM only the local row so muxes can slide.
# Rip only the touched nets; keep all other wires.
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
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set c8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_8]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

proc addbuf {block master instname pin x y bufname} {
  set inst [$block findInst $instname]
  set it [$inst findITerm $pin]
  set old [$it getNet]
  set buf [odb::dbInst_create $block $master $bufname]
  $buf setOrient R0
  $buf setLocation $x $y
  $buf setPlacementStatus PLACED
  set mid [odb::dbNet_create $block ${bufname}_i]
  odb::dbITerm_disconnect $it
  odb::dbITerm_connect $it $mid
  odb::dbITerm_connect [$buf findITerm I] $mid
  odb::dbITerm_connect [$buf findITerm Z] $old
  puts "BUF $bufname after $instname/$pin old=[$old getName]"
  return [list $mid $old]
}

# Un-FIRM stdcells (not DFF/SRAM/tap) in a band around each driver so they can slide.
proc unfirm_band {block x0 y0 xspan yspan} {
  foreach inst [$block getInsts] {
    set mn [[$inst getMaster] getName]
    if {[string match "*dff*" $mn] || [string match "*sram*" $mn] || [string match "*filltie*" $mn]} continue
    set bb [$inst getBBox]
    set cx [expr {([$bb xMin]+[$bb xMax])/2}]
    set cy [expr {([$bb yMin]+[$bb yMax])/2}]
    if {abs($cx-$x0) < $xspan && abs($cy-$y0) < $yspan} {
      $inst setPlacementStatus PLACED
    }
  }
}
unfirm_band $block 647360 2348640 200000 25000
unfirm_band $block 1543360 2691360 200000 25000

set p1 [addbuf $block $c8 _12379_ ZN 658560 2348640 elec_buf_12379]
set p2 [addbuf $block $c8 _11319_ ZN 1553440 2691360 elec_buf_11319]
# keep the drivers themselves FIRM
[$block findInst _12379_] setPlacementStatus FIRM
[$block findInst _11319_] setPlacementStatus FIRM

set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {400 80}} msg]} { puts "LEGALIZE_WARN $msg" }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }
foreach b {elec_buf_12379 elec_buf_11319} {
  set i [$block findInst $b]
  lassign [$i getLocation] x y
  puts "BUFLOC $b $x $y [$i getPlacementStatus]"
}

puts "ELEC22_ROUTE"
lassign $p1 mid1 old1
lassign $p2 mid2 old2
foreach n [list $mid1 $old1 $mid2 $old2] {
  if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
  catch {$n clearGuides}
  puts "RIP [$n getName]"
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/elec22.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/elec22.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_elec22.odb
write_def $eco/butterfold_top_elec22.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/elec22.max.spef
read_spef $eco/elec22.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
if {[catch {check_antennas} a]} { puts "ANT $a" }
if {[catch {check_placement}]} { puts "PLACE2_BAD" } else { puts "PLACE2_OK" }
catch {report_wns -max > $out/elec22_wns.rpt}
catch {report_tns -max > $out/elec22_tns.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/elec22_electrical.rpt}
puts "ELEC22_COMPLETE"
exit
