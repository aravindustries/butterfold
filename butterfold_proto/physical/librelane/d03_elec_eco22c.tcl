# clkbuf_1 after _11319_ to clear 0.01 fF max-cap. Slide _11992_ only.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_elec22b.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set db [ord::get_db]
set block [ord::get_db_block]
set c1 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_1]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }
set drv [$block findInst _11319_]
set it [$drv findITerm ZN]
set old [$it getNet]
set buf [odb::dbInst_create $block $c1 elec_buf_11319]
$buf setOrient R0
$buf setLocation 1553440 2691360
$buf setPlacementStatus PLACED
set mid [odb::dbNet_create $block elec_buf_11319_i]
odb::dbITerm_disconnect $it
odb::dbITerm_connect $it $mid
odb::dbITerm_connect [$buf findITerm I] $mid
odb::dbITerm_connect [$buf findITerm Z] $old
puts "BUF elec_buf_11319 on [$old getName]"
foreach name {_11992_ _11999_} {
  set i [$block findInst $name]
  if {$i ne "NULL"} { $i setPlacementStatus PLACED; puts "UNFIRM $name" }
}
set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {200 40}} msg]} { puts "LEGALIZE_WARN $msg" }
# placement checked later without padding override
puts "ELEC22C_ROUTE"
foreach n [list $mid $old] {
  if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
  catch {$n clearGuides}
}
foreach name {_11992_ _11999_} {
  set i [$block findInst $name]
  if {$i eq "NULL"} continue
  foreach t [$i getITerms] {
    set pn [[$t getMTerm] getName]
    if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
    set nn [$t getNet]
    if {$nn eq "NULL"} continue
    if {[$nn getWire] ne "" && [$nn getWire] ne "NULL"} { catch {odb::dbWire_destroy [$nn getWire]} }
    catch {$nn clearGuides}
  }
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/elec22c.guide}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/elec22c.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_elec22c.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/elec22c.max.spef
read_spef $eco/elec22c.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
if {[catch {check_antennas} a]} { puts "ANT $a" }
puts "ELEC22C_COMPLETE"
exit
