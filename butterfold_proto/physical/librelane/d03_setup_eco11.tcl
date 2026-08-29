# ECO11: size _20055_ dffrnq_2 (3.03 ns CLK-Q on all remaining paths)
# plus leftover nand2_1 / buf_4 / electrical. From eco10.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco10_routed.odb
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
  puts "SWAP $inst [[$i getMaster] getName]"
  return 1
}
eco_swap $block $db _20055_ gf180mcu_fd_sc_mcu9t5v0__dffrnq_4
eco_swap $block $db _15861_ gf180mcu_fd_sc_mcu9t5v0__nand2_4
eco_swap $block $db max_cap23 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
eco_swap $block $db _18516_ gf180mcu_fd_sc_mcu9t5v0__dffq_4

# electrical driver
foreach name {_12371_ _09609_} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { continue }
  set mn [[$i getMaster] getName]
  puts "ELEC $name $mn"
  if {[regexp {^(gf180mcu_fd_sc_mcu9t5v0__.+_)([1248])$} $mn -> stem stren]} {
    if {$stren < 4} {
      set tgt ${stem}4
    } elseif {$stren == 4} {
      set tgt ${stem}8
      if {[$db findMaster $tgt] eq "NULL"} { set tgt "" }
    } else { set tgt "" }
    if {$tgt ne ""} {
      eco_swap $block $db $name $tgt
    }
  }
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO11_REROUTE"
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
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco11.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco11.drc
write_db $eco/butterfold_top_eco11_routed.odb
write_def $eco/butterfold_top_eco11_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco11.max.spef
  read_spef $eco/eco11.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO11_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco11_spef_wns.rpt}
catch {report_tns -max > $out/eco11_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco11_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco11_spef_electrical.rpt}
puts "ECO11_COMPLETE"
exit
