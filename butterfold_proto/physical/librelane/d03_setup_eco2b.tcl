# ECO2b: downsize illegal max_cap clkbuf_20 in place, force-place if needed, re-route.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco2_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set m8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_8]
set inv8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkinv_8]
set x 200000
set y 400000
foreach name {max_cap186 max_cap139 max_cap138 max_cap185 max_cap106 max_cap107 clkload3} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $name"; continue }
  set mn [[$i getMaster] getName]
  puts "FIX $name $mn"
  if {[string match "*clkbuf_20*" $mn] && $m8 ne "NULL"} {
    $i swapMaster $m8
    puts "  clkbuf_20 -> clkbuf_8"
  }
  if {[string match "*clkinv_20*" $mn] && $inv8 ne "NULL"} {
    $i swapMaster $inv8
    puts "  clkinv_20 -> clkinv_8"
  }
  $i setOrient R0
  $i setLocation $x $y
  $i setPlacementStatus PLACED
  incr x 40000
}
set_placement_padding -global -left 2 -right 2
detailed_placement -max_displacement {800 200}
if {[catch {check_placement -verbose} cmsg]} {
  puts "CHECK_PLACEMENT $cmsg"
} else {
  puts "CHECK_PLACEMENT_OK"
}

puts "ECO2B_REROUTE"
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
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco2b.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco2b.drc
write_db $eco/butterfold_top_eco2b_routed.odb
write_def $eco/butterfold_top_eco2b_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco2b.max.spef
  read_spef $eco/eco2b.max.spef
} emsg]} {
  puts "EXTRACT_WARN $emsg"
}
puts "ECO2B_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco2b_spef_wns.rpt}
catch {report_tns -max > $out/eco2b_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco2b_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco2b_spef_electrical.rpt}
puts "ECO2B_COMPLETE"
exit
