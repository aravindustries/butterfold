# Screen local swaps on teco12 WITHOUT ripping wires.
# Compare placement-RC and extract-with-existing-wires.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/butterfold_top_co6a36_teco12.odb
puts "ECO_SRC $src"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}
set db [ord::get_db]
set block [ord::get_db_block]
set rcx $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max

proc do_swap {block db inst tgt} {
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; return 0 }
  set src [[$i getMaster] getName]
  set m [$db findMaster $tgt]
  if {$m eq "NULL"} { puts "NOMASTER $tgt"; return 0 }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg"; return 0 }
  puts "SWAP $inst $src -> $tgt"
  return 1
}

puts "CANDIDATE rebuffer265 clkbuf_8->clkbuf_16 (no legalize, keep wires)"
do_swap $block $db rebuffer265 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
estimate_parasitics -placement
puts "PLACE_RC_WNS"; report_wns -max
puts "PLACE_RC_TNS"; report_tns -max
extract_parasitics -ext_model_file $rcx
puts "EXTRACT_KEEPWIRES_WNS"; report_wns -max
puts "EXTRACT_KEEPWIRES_TNS"; report_tns -max
report_checks -path_delay max -group_path_count 6
puts "EVAL_DONE"
exit
