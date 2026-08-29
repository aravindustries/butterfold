# ECO16b from eco15 (WNS -0.06). Do NOT rip CLOCK. FIRM sequential
# cells. Size WNS-path tail buf_8 and electrical only.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco15_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]

foreach name {max_cap46 fanout244} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $name"; continue }
  if {[catch {$i swapMaster $c16} msg]} { puts "SWAP_FAIL $name $msg" } else { puts "SWAP $name" }
}
set e [$block findInst _12503_]
if {$e ne "NULL" && $e ne ""} {
  set mn [[$e getMaster] getName]
  puts "ELEC _12503_ $mn"
  if {[regexp {^(gf180mcu_fd_sc_mcu9t5v0__.+_)([12])$} $mn -> stem stren]} {
    set m [$db findMaster ${stem}4]
    if {$m ne "NULL"} { catch {$e swapMaster $m}; puts "ELEC_SWAP" }
  }
}

# Freeze sequential + SRAM so clock routes stay valid.
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match "*dff*" $mn] || [string match "*sram*" $mn] || [string match "*lat*" $mn]} {
    $inst setPlacementStatus FIRM
  }
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO16B_REROUTE"
foreach net [$block getNets] {
  set st [$net getSigType]
  if {[string match *POWER* $st] || [string match *GROUND* $st] || [string match *CLOCK* $st]} { continue }
  set nn [$net getName]
  if {[string match "clknet_*" $nn] || [string match "eco14_skew*" $nn] || [string match "eco15_*" $nn] || [string match "eco16_*" $nn]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    catch {odb::dbWire_destroy [$net getWire]}
  }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
catch {global_connect}
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco16b.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco16b.drc
write_db $eco/butterfold_top_eco16b_routed.odb
write_def $eco/butterfold_top_eco16b_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco16b.max.spef
  read_spef $eco/eco16b.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO16B_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco16b_spef_wns.rpt}
catch {report_tns -max > $out/eco16b_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 20 > $out/eco16b_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco16b_spef_electrical.rpt}
puts "ECO16B_COMPLETE"
exit
