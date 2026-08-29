# ECO14: close last 0.35 ns.
# 1) remaining _1/_2 on violators + dffq_1 endpoints
# 2) useful-skew: clkbuf_16 only on the 40 capture CLK pins (not launch leaf_9)
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco13_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
proc eco_swap {block db inst tgt} {
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; return 0 }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt"; return 0 }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg"; return 0 }
  puts "SWAP $inst"
  return 1
}
foreach inst {_16111_} { eco_swap $block $db $inst gf180mcu_fd_sc_mcu9t5v0__nand2_4 }
foreach inst {_15965_ _16138_} { eco_swap $block $db $inst gf180mcu_fd_sc_mcu9t5v0__nor2_4 }
foreach inst {
  _18315_ _18317_ _18318_ _18320_ _18321_ _18323_
  _18429_ _18430_ _18431_ _18509_ _18513_ _18514_ _18515_
} { eco_swap $block $db $inst gf180mcu_fd_sc_mcu9t5v0__dffq_4 }

set e [$block findInst _12458_]
if {$e ne "NULL" && $e ne ""} {
  set mn [[$e getMaster] getName]
  puts "ELEC _12458_ $mn"
  if {[regexp {^(gf180mcu_fd_sc_mcu9t5v0__.+_)([12])$} $mn -> stem stren]} {
    eco_swap $block $db _12458_ ${stem}4
  }
}

# Useful skew: one clkbuf_16 per capture leaf, only the 40 endpoint CLK pins.
set endpoints {
  _18433_ _18279_ _18427_ _18238_ _18243_ _18277_ _18326_ _18321_
  _18327_ _18518_ _18324_ _18322_ _18328_ _18325_ _18315_ _18429_
  _18516_ _18273_ _18240_ _18432_ _18318_ _18501_ _18515_ _18323_
  _18317_ _18514_ _18513_ _18173_ _18304_ _18320_ _18509_ _18276_
  _18500_ _18307_ _18495_ _18278_ _18496_ _18430_ _18431_ _18491_
}
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
# map leaf-net-name -> list of CLK iterms
array set leaf_loads {}
foreach name $endpoints {
  set inst [$block findInst $name]
  if {$inst eq "NULL" || $inst eq ""} { puts "NOEND $name"; continue }
  set clk [$inst findITerm CLK]
  if {$clk eq "NULL" || $clk eq ""} { continue }
  set n [$clk getNet]
  if {$n eq "NULL"} { continue }
  set nn [$n getName]
  if {$nn eq "clknet_leaf_9_clk_regs"} {
    puts "SKIP_LAUNCH_LEAF $name"
    continue
  }
  lappend leaf_loads($nn) $clk
}
set nbuf 0
foreach nn [array names leaf_loads] {
  set net [$block findNet $nn]
  set loads $leaf_loads($nn)
  set buf [odb::dbInst_create $block $c16 eco14_skew_$nbuf]
  # place near first load
  set inst0 [[lindex $loads 0] getInst]
  lassign [$inst0 getLocation] x y
  $buf setOrient R0
  $buf setLocation [expr {$x + 2240}] [expr {$y + 5040}]
  $buf setPlacementStatus PLACED
  set n2 [odb::dbNet_create $block eco14_skew_net_$nbuf]
  odb::dbITerm_connect [$buf findITerm I] $net
  odb::dbITerm_connect [$buf findITerm Z] $n2
  foreach it $loads {
    odb::dbITerm_disconnect $it
    odb::dbITerm_connect $it $n2
  }
  puts "SKEW_BUF eco14_skew_$nbuf leaf=$nn loads=[llength $loads]"
  incr nbuf
}
puts "ECO14_SKEW_BUFS $nbuf"

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO14_REROUTE"
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
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco14.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco14.drc
write_db $eco/butterfold_top_eco14_routed.odb
write_def $eco/butterfold_top_eco14_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco14.max.spef
  read_spef $eco/eco14.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO14_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco14_spef_wns.rpt}
catch {report_tns -max > $out/eco14_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco14_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco14_spef_electrical.rpt}
puts "ECO14_COMPLETE"
exit
