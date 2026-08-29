# ECO3: size remaining violator _1/_2 cells to _4; repair_design for rst_n slew; re-route.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco2b_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set nswap 0
set fh [open $eco/eco3_swaps.txt r]
while {[gets $fh line] >= 0} {
  if {[string trim $line] eq ""} { continue }
  lassign $line inst src tgt
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { continue }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt"; continue }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg" } else { incr nswap }
}
close $fh
puts "ECO3_SWAPPED $nswap"

# Strengthen SRAM data/addr drivers on the remaining path.
foreach inst_name {
  u_transform_scheduler_core.u_fft_scratch_sram.u_hi.g_pin_drive[3].u_data_driver
  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.g_pin_drive[3].u_data_driver
} {
  set i [$block findInst $inst_name]
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_16]
  if {$i ne "NULL" && $i ne "" && $m ne "NULL"} {
    catch {$i swapMaster $m}
    puts "SRAM_DRV $inst_name -> buf_16"
  }
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {500 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}

read_spef $eco/eco2b.max.spef
if {[catch {repair_design -slew_margin 30 -cap_margin 20} rdmsg]} {
  puts "REPAIR_DESIGN_WARN $rdmsg"
}
estimate_parasitics -placement
if {[catch {repair_timing -setup -setup_margin 0.3 -repair_tns 100 -max_buffer_percent 20} rtmsg]} {
  puts "REPAIR_TIMING_WARN $rtmsg"
}
estimate_parasitics -placement
puts "ECO3_PLACEMENT_WNS"
report_wns -max
report_tns -max

if {[catch {detailed_placement -max_displacement {500 200}} msg]} {
  puts "LEGALIZE2_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO3_REROUTE"
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
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco3.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco3.drc
write_db $eco/butterfold_top_eco3_routed.odb
write_def $eco/butterfold_top_eco3_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco3.max.spef
  read_spef $eco/eco3.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO3_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco3_spef_wns.rpt}
catch {report_tns -max > $out/eco3_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco3_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco3_spef_electrical.rpt}
puts "ECO3_COMPLETE"
exit
