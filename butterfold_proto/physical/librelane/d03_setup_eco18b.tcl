# ECO18b from eco16b: swap SRAM GWEN cells, legalize ONLY those
# instances (everyone else FIRM), keep all wires, re-extract.
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
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5

set db [ord::get_db]
set block [ord::get_db_block]
set n3 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__nor3_4]
set inv8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkinv_8]

foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set i [$block findInst _09881_]
catch {$i swapMaster $n3}
$i setPlacementStatus PLACED
puts "SWAP _09881_"
foreach name {
  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_gwen_driver
  u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_gwen_driver
} {
  set j [$block findInst $name]
  if {$j ne "NULL" && $j ne ""} {
    catch {$j swapMaster $inv8}
    $j setPlacementStatus PLACED
    puts "SWAP $name"
  }
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {200 50}} msg]} { puts "LEGALIZE_WARN $msg" }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

write_db $eco/butterfold_top_eco18b.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco18b.max.spef
  read_spef $eco/eco18b.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO18B_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco18b_spef_wns.rpt}
catch {report_tns -max > $out/eco18b_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 10 > $out/eco18b_spef_violations.rpt}
puts "ECO18B_COMPLETE"
exit
