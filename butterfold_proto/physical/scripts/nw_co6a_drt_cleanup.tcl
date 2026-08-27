# Targeted DRT cleanup of the 3 leftover shorts/spacing after aoi221 swap.
# 26Q2 OpenROAD; write DEF for Magic. Do not feed this ODB to LibreLane.
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set out $proto_root/physical/results/nw_pins_eco/co6a_repair

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__tt_025C_5v00.lib
read_db $out/routed.odb
read_sdc $proto_root/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]

set block [ord::get_db_block]
set names {
  _03875_
  net1127
  _04749_
  _04816_
  {u_transform_scheduler_core.bf_X0_i[10]}
}
foreach name $names {
  set net [$block findNet $name]
  if {$net eq "" || $net eq "NULL"} {
    puts "MISSING_NET $name"
    continue
  }
  puts "RIP [$net getName]"
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    odb::dbWire_destroy [$net getWire]
  }
  $net clearGuides
}

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.4
}
global_route -congestion_iterations 50 -verbose -guide_file $out/cleanup.guide
# Keep stubborn-tile budget modest; only a handful of nets are open.
detailed_route -droute_end_iter 16 -or_seed 7 -verbose 1 -output_drc $out/cleanup.drc
puts "CLEANUP_DRT_DONE"
if {[catch {check_antennas -report_file $out/cleanup_antenna.rpt} amsg]} { puts "ANTENNA $amsg" }
write_db $out/routed.odb
write_def $out/routed.def
write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
puts "CLEANUP_DONE"
exit
