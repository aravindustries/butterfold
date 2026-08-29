# Flip bottom-row ECO cells R0 -> MX (that row is MX), global_connect,
# rip only their signal nets, re-route, recheck PG/timing/antenna.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_elec22c.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set block [ord::get_db_block]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set names {eco18_sk_18433 hold_dlya_din0 hold_dlya_din1 hold_dlya_din2}
foreach n $names {
  set i [$block findInst $n]
  $i setPlacementStatus PLACED
  $i setOrient MX
  puts "ORI $n MX"
}
set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {200 40}} msg]} { puts "LEGALIZE_WARN $msg" }

catch {global_connect}

# Rip signal nets attached to these four cells (not PG).
foreach n $names {
  set i [$block findInst $n]
  foreach t [$i getITerms] {
    set pn [[$t getMTerm] getName]
    if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
    set nn [$t getNet]
    if {$nn eq "NULL"} continue
    if {[$nn getWire] ne "" && [$nn getWire] ne "NULL"} { catch {odb::dbWire_destroy [$nn getWire]} }
    catch {$nn clearGuides}
    puts "RIP [$nn getName]"
  }
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/pg23.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/pg23.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
write_db $eco/butterfold_top_pg23.odb
write_def $eco/butterfold_top_pg23.def

puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" }

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $eco/pg23.max.spef
read_spef $eco/pg23.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
if {[catch {check_antennas} a]} { puts "ANT $a" }
# default placement check (no extra padding)
# re-open would be cleaner; try after clearing padding by not checking here
puts "PG23_COMPLETE"
exit
