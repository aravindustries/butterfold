# ECO8b from eco7 (eco8 mux2 upsizing regressed WNS).
# Remove Q-prefix buffer that added 0.38 ns to WNS path.
# Swap only high-delay (>=1.15 ns) _1/_2 cells, no mux2.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco7_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]

# Remove eco7_buf_18691: it added 0.38 ns on the WNS path.
set buf [$block findInst eco7_buf_18691]
if {$buf ne "NULL" && $buf ne ""} {
  set itermI [$buf findITerm I]
  set itermZ [$buf findITerm Z]
  set mid [$itermI getNet]
  set old [$itermZ getNet]
  set drv [[$block findInst _18691_] findITerm Q]
  if {$drv ne "NULL" && $drv ne "" && $old ne "NULL"} {
    catch {odb::dbITerm_disconnect $drv}
    catch {odb::dbITerm_disconnect $itermI}
    catch {odb::dbITerm_disconnect $itermZ}
    odb::dbITerm_connect $drv $old
    catch {odb::dbInst_destroy $buf}
    if {$mid ne "NULL" && $mid ne ""} { catch {odb::dbNet_destroy $mid} }
    puts "REMOVED eco7_buf_18691; _18691_/Q reconnected to [$old getName]"
  }
}

set nswap 0
set fh [open $eco/eco8b_swaps.txt r]
while {[gets $fh line] >= 0} {
  if {[string trim $line] eq ""} { continue }
  lassign $line inst src tgt
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; continue }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt"; continue }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg" } else { incr nswap }
}
close $fh
puts "ECO8B_SWAPPED $nswap"

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO8B_REROUTE"
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
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco8b.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco8b.drc
write_db $eco/butterfold_top_eco8b_routed.odb
write_def $eco/butterfold_top_eco8b_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco8b.max.spef
  read_spef $eco/eco8b.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO8B_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco8b_spef_wns.rpt}
catch {report_tns -max > $out/eco8b_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco8b_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco8b_spef_electrical.rpt}
puts "ECO8B_COMPLETE"
exit
