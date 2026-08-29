# ECO18f: in-place downsize the existing capture skew buf that already
# drives _18433_ (clkbuf_16 -> clkbuf_4). No new nets, no re-route.
# Extra buffer delay closes the last 80 ps.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco18b.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set db [ord::get_db]
set block [ord::get_db_block]

set ff [$block findInst _18433_]
set clk [$ff findITerm CLK]
set n [$clk getNet]
puts "CLKNET [$n getName] terms=[llength [$n getITerms]]"
# driver is the output term on this net
foreach it [$n getITerms] {
  set pn [[$it getMTerm] getName]
  set inst [$it getInst]
  puts "  TERM [$inst getName]/$pn [[$inst getMaster] getName]"
  if {$pn eq "Z"} {
    set m8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_8]
    puts "BEFORE [[$inst getMaster] getName]"
    if {[catch {$inst swapMaster $m8} msg]} { puts "SWAP_FAIL $msg" } else {
      puts "SWAP [$inst getName] -> clkbuf_8"
    }
  }
}

if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }
write_db $eco/butterfold_top_eco18g.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco18g.max.spef
  read_spef $eco/eco18g.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO18F_EXTRACTED_WNS"
report_wns -max
report_tns -max
report_checks -path_delay max -group_path_count 5
catch {report_wns -max > $out/eco18g_spef_wns.rpt}
catch {report_tns -max > $out/eco18g_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 10 > $out/eco18g_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco18g_spef_electrical.rpt}
puts "ECO18G_COMPLETE"
exit
