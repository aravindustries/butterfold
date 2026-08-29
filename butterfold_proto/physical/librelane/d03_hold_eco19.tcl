# Hold ECO from eco18i. Delay din[0..2] after input1/2/3 with dlya_4
# placed in known-legal holes. Keep existing wires; full GRT+DRT.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $eco/butterfold_top_eco18i.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set dlya [$db findMaster gf180mcu_fd_sc_mcu9t5v0__dlya_4]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

proc insert_dlya {block master srcname locx locy bufname} {
  set src [$block findInst $srcname]
  if {$src eq "NULL" || $src eq ""} { puts "NO $srcname"; return 0 }
  set z [$src findITerm Z]
  set old [$z getNet]
  set buf [odb::dbInst_create $block $master $bufname]
  $buf setOrient R0
  $buf setLocation $locx $locy
  $buf setPlacementStatus FIRM
  set mid [odb::dbNet_create $block ${bufname}_i]
  odb::dbITerm_disconnect $z
  odb::dbITerm_connect $z $mid
  odb::dbITerm_connect [$buf findITerm I] $mid
  odb::dbITerm_connect [$buf findITerm Z] $old
  puts "HOLD_DLY $bufname after $srcname at $locx $locy"
  return 1
}
insert_dlya $block $dlya input1 963200 50400 hold_dlya_din0
insert_dlya $block $dlya input2 1052800 50400 hold_dlya_din1
insert_dlya $block $dlya input3 896000 50400 hold_dlya_din2

if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "HOLD_ROUTE"
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/hold19.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/hold19.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_hold19.odb
write_def $eco/butterfold_top_hold19.def

set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
if {[catch {
  extract_parasitics -ext_model_file $rcx_min
  write_spef $eco/hold19.min.spef
  read_spef $eco/hold19.min.spef
} emsg]} { puts "EXTRACT_MIN $emsg" }
puts "HOLD_WNS"
report_wns -min
report_tns -min
catch {report_wns -min > $out/hold19_wns.rpt}
catch {report_tns -min > $out/hold19_tns.rpt}
catch {report_checks -path_delay min -slack_max 0 -group_path_count 20 > $out/hold19_violations.rpt}
if {[catch {check_placement -verbose} m2]} { puts "PLACE2 $m2" } else { puts "PLACE2_OK" }
puts "HOLD19_COMPLETE"
exit
