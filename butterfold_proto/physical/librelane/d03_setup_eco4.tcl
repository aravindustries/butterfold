# ECO4: remaining path _4 swaps + rst_n buffer tree + re-route.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco3_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set nswap 0
set fh [open $eco/eco4_swaps.txt r]
while {[gets $fh line] >= 0} {
  if {[string trim $line] eq ""} { continue }
  lassign $line inst src tgt
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { continue }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt"; continue }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg" } else { incr nswap }
}
close $fh
set fan [$block findInst fanout243]
set m16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
if {$fan ne "NULL" && $fan ne "" && $m16 ne "NULL"} {
  catch {$fan swapMaster $m16}
  puts "FANOUT243 -> clkbuf_16"
}
puts "ECO4_SWAPPED $nswap"

# rst_n tree: 1 root + 8 mid + 64 leaf clkbuf_16
set rstnet [$block findNet rst_n]
set clkbuf [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
set loads {}
foreach iterm [$rstnet getITerms] {
  set inst [$iterm getInst]
  set iname [$inst getName]
  if {[string match "rst_tree_*" $iname]} { continue }
  lappend loads $iterm
}
puts "RST_LOADS [llength $loads]"
set y0 80000
set x0 120000
proc place_buf {block master name x y} {
  set inst [odb::dbInst_create $block $master $name]
  $inst setOrient R0
  $inst setLocation $x $y
  $inst setPlacementStatus PLACED
  return $inst
}
set root [place_buf $block $clkbuf rst_tree_root $x0 $y0]
set rst_l1 [odb::dbNet_create $block rst_l1]
odb::dbITerm_connect [$root findITerm I] $rstnet
odb::dbITerm_connect [$root findITerm Z] $rst_l1
set mids {}
for {set i 0} {$i < 8} {incr i} {
  set mx [expr {$x0 + ($i % 8) * 40000}]
  set my [expr {$y0 + 20160}]
  set mi [place_buf $block $clkbuf rst_tree_mid_$i $mx $my]
  set nmid [odb::dbNet_create $block rst_m$i]
  odb::dbITerm_connect [$mi findITerm I] $rst_l1
  odb::dbITerm_connect [$mi findITerm Z] $nmid
  lappend mids $nmid
}
set leaves {}
for {set i 0} {$i < 64} {incr i} {
  set mx [expr {$x0 + ($i % 16) * 28000}]
  set my [expr {$y0 + 40320 + ($i / 16) * 10080}]
  set li [place_buf $block $clkbuf rst_tree_leaf_$i $mx $my]
  set nleaf [odb::dbNet_create $block rst_lf$i]
  set midnet [lindex $mids [expr {$i / 8}]]
  odb::dbITerm_connect [$li findITerm I] $midnet
  odb::dbITerm_connect [$li findITerm Z] $nleaf
  lappend leaves $nleaf
}
set nload [llength $loads]
set idx 0
foreach iterm $loads {
  set leaf [lindex $leaves [expr {$idx % 64}]]
  if {[$iterm getNet] ne "NULL"} { odb::dbITerm_disconnect $iterm }
  odb::dbITerm_connect $iterm $leaf
  incr idx
}
puts "RST_TREE_CONNECTED $idx loads onto 64 leaves"

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO4_REROUTE"
foreach net [$block getNets] {
  set st [$net getSigType]
  if {[string match *POWER* $st] || [string match *GROUND* $st]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    catch {odb::dbWire_destroy [$net getWire]}
  }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
catch {global_connect}
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco4.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco4.drc
write_db $eco/butterfold_top_eco4_routed.odb
write_def $eco/butterfold_top_eco4_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco4.max.spef
  read_spef $eco/eco4.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO4_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco4_spef_wns.rpt}
catch {report_tns -max > $out/eco4_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco4_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco4_spef_electrical.rpt}
puts "ECO4_COMPLETE"
exit
