# Hold + PG + geometry + cap-driver probe on eco18i (setup-closed candidate).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ff_n40C_5v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ff_n40C_5v50.lib
read_db $eco/butterfold_top_eco18i.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]

set rcx_min $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.min
if {[catch {
  extract_parasitics -ext_model_file $rcx_min
  write_spef $eco/eco18i.min.spef
  read_spef $eco/eco18i.min.spef
} emsg]} { puts "EXTRACT_MIN_WARN $emsg" }
puts "HOLD_WNS"
report_wns -min
puts "HOLD_TNS"
report_tns -min
catch {report_wns -min > $out/eco18i_hold_wns.rpt}
catch {report_tns -min > $out/eco18i_hold_tns.rpt}
catch {report_checks -path_delay min -slack_max 0 -group_path_count 20 > $out/eco18i_hold_violations.rpt}

set block [ord::get_db_block]
puts "DIE [$block getDieArea]"
puts "CORE [$block getCoreArea]"
puts "BTERMS [llength [$block getBTerms]]"
foreach t [$block getBTerms] {
  set box [$t getBBox]
  puts "PIN [$t getName] [$box xMin] [$box yMin] [$box xMax] [$box yMax]"
}
set i [$block findInst _11319_]
if {$i ne "NULL"} { puts "CAPDRV [_11319_ missing]" }
if {$i ne "NULL" && $i ne ""} { puts "CAPDRV [[$i getMaster] getName]" }

if {[catch {check_power_grid -net VDD} e1]} { puts "VDD_GRID $e1" }
if {[catch {check_power_grid -net VSS} e2]} { puts "VSS_GRID $e2" }
puts "HOLD_PG_DONE"
exit
