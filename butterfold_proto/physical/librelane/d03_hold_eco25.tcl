# Move hold dlya cells next to din input buffers (short mid nets).
# Fixes antenna on hold_dlya_*_i. Keep eco18_sk. From pg23_stitch.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_pg23_stitch.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set block [ord::get_db_block]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

proc move_dlya {block name x y} {
  set i [$block findInst $name]
  $i setPlacementStatus PLACED
  $i setOrient MX
  $i setLocation $x $y
  $i setPlacementStatus FIRM
  puts "MOVE $name $x $y MX"
  foreach t [$i getITerms] {
    set pn [[$t getMTerm] getName]
    if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
    set n [$t getNet]
    if {$n eq "NULL"} continue
    if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
    catch {$n clearGuides}
    puts "RIP [$n getName]"
  }
}
move_dlya $block hold_dlya_din0 26880 2348640
move_dlya $block hold_dlya_din1 24640 2147040
move_dlya $block hold_dlya_din2 24640 1945440
catch {global_connect}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE $cmsg" } else { puts "PLACE_OK" }

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/hold25.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/hold25.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_hold25.odb

puts "ANT"
catch {check_antennas}
puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/hold25.max.spef
read_spef $eco/hold25.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
puts "HOLD25_COMPLETE"
exit
