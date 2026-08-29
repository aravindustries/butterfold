# Local clkbuf_4 after _12379_. Slide only two neighboring mux2_1 cells.
# From ant20b. Rip only mid+_06907_.
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
set c4 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_4]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set drv [$block findInst _12379_]
set it [$drv findITerm ZN]
set old [$it getNet]
set buf [odb::dbInst_create $block $c4 elec_buf_12379]
$buf setOrient R0
$buf setLocation 658560 2348640
$buf setPlacementStatus PLACED
set mid [odb::dbNet_create $block elec_buf_12379_i]
odb::dbITerm_disconnect $it
odb::dbITerm_connect $it $mid
odb::dbITerm_connect [$buf findITerm I] $mid
odb::dbITerm_connect [$buf findITerm Z] $old
puts "BUF elec_buf_12379 on [$old getName]"

foreach name {_16897_ _16788_ _11719_} {
  set i [$block findInst $name]
  if {$i ne "NULL" && $i ne ""} { $i setPlacementStatus PLACED; puts "UNFIRM $name" }
}

set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {200 40}} msg]} { puts "LEGALIZE_WARN $msg" }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }
lassign [$buf getLocation] bx by
puts "BUFLOC $bx $by"

puts "ELEC22B_ROUTE"
foreach n [list $mid $old] {
  if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
  catch {$n clearGuides}
  puts "RIP [$n getName]"
}
# also rip nets of the 3 slid muxes (their pins moved)
foreach name {_16897_ _16788_ _11719_} {
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
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/elec22b.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/elec22b.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_elec22b.odb

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/elec22b.max.spef
read_spef $eco/elec22b.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
if {[catch {check_antennas} a]} { puts "ANT $a" }
if {[catch {check_placement}]} { puts "PLACE2_BAD" } else { puts "PLACE2_OK" }
catch {report_wns -max > $out/elec22b_wns.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/elec22b_electrical.rpt}
puts "ELEC22B_COMPLETE"
exit
