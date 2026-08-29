# ECO15: remaining violator endpoints were not in the eco14 skew set.
# Add two clkbuf_16 in series on those capture CLK pins. Also size
# max_cap48 on the WNS path. Skip SRAM CLK.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco14_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]

set i [$block findInst max_cap48]
if {$i ne "NULL" && $i ne "" && $c16 ne "NULL"} {
  catch {$i swapMaster $c16}
  puts "SWAP max_cap48"
}

set endpoints {
  _18497_ _18301_ _18302_ _18237_ _18507_ _18433_ _18510_ _18170_
  _18366_ _18361_ _18370_ _18238_ _18326_ _18427_ _18516_ _18315_
  _18429_ _18453_ _18260_ _18243_ _18318_ _18327_ _18328_ _18240_
  _18325_ _18365_ _18518_ _18369_ _18501_ _18481_ _18432_ _18286_
  _18258_ _18304_ _18324_ _18291_ _18322_ _18317_
}

# Group CLK iterms whose current net is still a CTS leaf (not already eco14/eco15 skew).
array set leaf_loads {}
set nskip 0
foreach name $endpoints {
  set inst [$block findInst $name]
  if {$inst eq "NULL" || $inst eq ""} { continue }
  set clk [$inst findITerm CLK]
  if {$clk eq "NULL" || $clk eq ""} { continue }
  set n [$clk getNet]
  if {$n eq "NULL"} { continue }
  set nn [$n getName]
  if {[string match "clknet_leaf_9_*" $nn]} { incr nskip; continue }
  if {[string match "eco14_skew_net_*" $nn] || [string match "eco15_*" $nn]} {
    incr nskip
    continue
  }
  if {[string match "*sram*" $name] || [string match "*u_sram*" $name]} { continue }
  lappend leaf_loads($nn) $clk
}
puts "ECO15_SKIP_ALREADY $nskip"
set nbuf 0
foreach nn [array names leaf_loads] {
  set net [$block findNet $nn]
  set loads $leaf_loads($nn)
  # two clkbuf_16 in series
  set b1 [odb::dbInst_create $block $c16 eco15_sk1_$nbuf]
  set b2 [odb::dbInst_create $block $c16 eco15_sk2_$nbuf]
  set inst0 [[lindex $loads 0] getInst]
  lassign [$inst0 getLocation] x y
  $b1 setOrient R0
  $b1 setLocation [expr {$x + 2240}] [expr {$y + 5040}]
  $b1 setPlacementStatus PLACED
  $b2 setOrient R0
  $b2 setLocation [expr {$x + 4480}] [expr {$y + 5040}]
  $b2 setPlacementStatus PLACED
  set mid [odb::dbNet_create $block eco15_mid_$nbuf]
  set n2 [odb::dbNet_create $block eco15_net_$nbuf]
  odb::dbITerm_connect [$b1 findITerm I] $net
  odb::dbITerm_connect [$b1 findITerm Z] $mid
  odb::dbITerm_connect [$b2 findITerm I] $mid
  odb::dbITerm_connect [$b2 findITerm Z] $n2
  foreach it $loads {
    odb::dbITerm_disconnect $it
    odb::dbITerm_connect $it $n2
  }
  puts "SKEW2 eco15_sk*$nbuf leaf=$nn loads=[llength $loads]"
  incr nbuf
}
puts "ECO15_SKEW_PAIRS $nbuf"

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO15_REROUTE"
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
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco15.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco15.drc
write_db $eco/butterfold_top_eco15_routed.odb
write_def $eco/butterfold_top_eco15_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco15.max.spef
  read_spef $eco/eco15.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO15_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco15_spef_wns.rpt}
catch {report_tns -max > $out/eco15_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco15_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco15_spef_electrical.rpt}
puts "ECO15_COMPLETE"
exit
