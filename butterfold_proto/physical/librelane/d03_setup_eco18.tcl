# ECO18: in-place nor3_1->4 and gwen clkinv_8 on eco16b, NO legalize, NO
# re-route. Re-extract existing wires. Tests whether 80 ps SRAM GWEN
# closes without perturbing _18433_ routes.
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
set db [ord::get_db]
set block [ord::get_db_block]
set n3 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__nor3_4]
set inv8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkinv_8]
set i [$block findInst _09881_]
puts "BEFORE [[$i getMaster] getName]"
if {[catch {$i swapMaster $n3} msg]} { puts "SWAP_FAIL $msg" } else { puts "SWAP _09881_ [[$i getMaster] getName]" }
foreach name {
  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_gwen_driver
  u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_gwen_driver
} {
  set j [$block findInst $name]
  if {$j ne "NULL" && $inv8 ne "NULL"} {
    if {[catch {$j swapMaster $inv8} msg]} { puts "SWAP_FAIL $name $msg" } else { puts "SWAP $name" }
  }
}
write_db $eco/butterfold_top_eco18_inplace.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco18.max.spef
  read_spef $eco/eco18.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO18_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco18_spef_wns.rpt}
catch {report_tns -max > $out/eco18_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 20 > $out/eco18_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco18_spef_electrical.rpt}
puts "ECO18_COMPLETE"
exit
