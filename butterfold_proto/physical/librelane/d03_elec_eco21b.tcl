# Buffer remaining slew/cap nets into legal holes; keep-wire GRT/DRT.
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
  $buf setPlacementStatus FIRM
  set mid [odb::dbNet_create $block ${bufname}_i]
  odb::dbITerm_disconnect $it
  odb::dbITerm_connect $it $mid
  odb::dbITerm_connect [$buf findITerm I] $mid
  odb::dbITerm_connect [$buf findITerm Z] $old
  puts "ELEC_BUF $bufname after $instname/$pin old=[$old getName]"
  return $old
}
set n1 [addbuf $block $c8 _12379_ ZN 16800 40320 elec_buf_12379]
set n2 [addbuf $block $c8 _11319_ ZN 56000 40320 elec_buf_11319]
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg" } else { puts "PLACE_OK" }

# Rip only the touched nets
foreach nn [list [$n1 getName] [$n2 getName] elec_buf_12379_i elec_buf_11319_i] {
  set n [$block findNet $nn]
  if {$n eq "NULL"} continue
  if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
  catch {$n clearGuides}
  puts "RIP $nn"
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/elec21b.guide}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/elec21b.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_elec21b.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/elec21b.max.spef
read_spef $eco/elec21b.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
if {[catch {check_antennas} a]} { puts "ANT $a" }
if {[catch {check_placement}]} { puts "PLACE2_BAD" } else { puts "PLACE2_OK" }
puts "ELEC21B_COMPLETE"
exit
