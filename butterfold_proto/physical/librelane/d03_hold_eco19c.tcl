# Rip only the hold-delay nets that DRT-0206 flagged, keep all other wires.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $eco/butterfold_top_hold19.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set block [ord::get_db_block]
foreach nn {
  net1 net2 net3
  hold_dlya_din0_i hold_dlya_din1_i hold_dlya_din2_i
} {
  set n [$block findNet $nn]
  if {$n eq "NULL" || $n eq ""} { puts "MISSING $nn"; continue }
  if {[$n getWire] ne "" && [$n getWire] ne "NULL"} {
    catch {odb::dbWire_destroy [$n getWire]}
  }
  catch {$n clearGuides}
  puts "RIP $nn"
}

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/hold19c.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/hold19c.drc} dmsg]} {
  puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }

write_db $eco/butterfold_top_hold19c.odb
set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
extract_parasitics -ext_model_file $rcx_min
write_spef $eco/hold19c.min.spef
read_spef $eco/hold19c.min.spef
puts "HOLD_WNS"; report_wns -min
puts "HOLD_TNS"; report_tns -min
catch {report_wns -min > $out/hold19c_wns.rpt}
catch {report_tns -min > $out/hold19c_tns.rpt}
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "HOLD19C_COMPLETE"
exit
