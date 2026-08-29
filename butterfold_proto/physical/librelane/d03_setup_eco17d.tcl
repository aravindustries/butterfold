# ECO17d from eco16b. Size SRAM GWEN nor3_1. Preserve CLOCK. Optional
# skip_buffering repair_timing once (caught). No new clock cells.
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
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set n3 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__nor3_4]
set inv8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkinv_8]
set i [$block findInst _09881_]
if {$i ne "NULL" && $n3 ne "NULL"} {
  catch {$i swapMaster $n3}
  puts "SWAP _09881_"
}
foreach name {
  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_gwen_driver
  u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_gwen_driver
} {
  set j [$block findInst $name]
  if {$j ne "NULL" && $j ne "" && $inv8 ne "NULL"} {
    catch {$j swapMaster $inv8}
    puts "SWAP $name"
  }
}

foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match "*dff*" $mn] || [string match "*sram*" $mn]} {
    $inst setPlacementStatus FIRM
  }
}
set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}

# One bounded skip_buffering repair using existing SPEF. Do not hammer.
if {[catch {read_spef $eco/eco16b.max.spef} smsg]} { puts "SPEF_WARN $smsg" }
if {[catch {repair_timing -setup -skip_buffering -repair_tns 100 -setup_margin 0.15} rmsg]} {
  puts "REPAIR_TIMING_SKIPPED $rmsg"
} else {
  puts "REPAIR_TIMING_SKIP_BUFFERING_OK"
}
puts "POST_REPAIR_WNS"
report_wns -max
report_tns -max

if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE2_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO17D_REROUTE"
foreach net [$block getNets] {
  set st [$net getSigType]
  set nn [$net getName]
  if {[string match *POWER* $st] || [string match *GROUND* $st] || [string match *CLOCK* $st]} { continue }
  if {[string match "clknet_*" $nn] || [string match "eco14_skew*" $nn] || [string match "eco15_*" $nn] || [string match "eco16*" $nn] || [string match "eco17*" $nn]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    catch {odb::dbWire_destroy [$net getWire]}
  }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
catch {global_connect}
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco17d.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco17d.drc
write_db $eco/butterfold_top_eco17d_routed.odb
write_def $eco/butterfold_top_eco17d_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco17d.max.spef
  read_spef $eco/eco17d.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO17D_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco17d_spef_wns.rpt}
catch {report_tns -max > $out/eco17d_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 20 > $out/eco17d_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco17d_spef_electrical.rpt}
puts "ECO17D_COMPLETE"
exit
