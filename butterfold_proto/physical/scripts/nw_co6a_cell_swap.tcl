# Native CO.6a repair: swap the six MX aoi221_2 instances to aoi221_1.
# Read the hold-ECO DEF with openroad-librelane (schema-safe). Do not use
# PATH OpenROAD 26Q2 write_db.
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
set eco $proto_root/physical/results/nw_pins_eco
set out $eco/co6a_repair
file mkdir $out

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__tt_025C_5v00.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__tt_025C_5v00.lib
read_def $eco/hold_eco/routed.def

set block [ord::get_db_block]
set db [ord::get_db]
set newm [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_1]
if {$newm eq "" || $newm eq "NULL"} {
  puts "FATAL no aoi221_1 master"
  exit 1
}

set names {_09888_ _10690_ _13682_ _13744_ _15985_ _17407_}
set rip_nets [dict create]
foreach name $names {
  set inst [$block findInst $name]
  if {$inst eq "" || $inst eq "NULL"} {
    puts "FATAL missing inst $name"
    exit 1
  }
  set old [[$inst getMaster] getName]
  set ori [$inst getOrient]
  puts "SWAP $name $old $ori -> aoi221_1"
  if {![$inst swapMaster $newm]} {
    puts "FATAL swapMaster failed $name"
    exit 1
  }
  puts "  NOW [[$inst getMaster] getName] [$inst getOrient]"
  foreach iterm [$inst getITerms] {
    set net [$iterm getNet]
    if {$net eq "" || $net eq "NULL"} { continue }
    set st [$net getSigType]
    if {[string match *POWER* $st] || [string match *GROUND* $st]} { continue }
    dict set rip_nets [$net getName] $net
  }
}

puts "RIP_NETS [dict size $rip_nets]"
dict for {nn net} $rip_nets {
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    odb::dbWire_destroy [$net getWire]
  }
  $net clearGuides
}

if {[catch {global_connect} gcmsg]} { puts "GLOBAL_CONNECT $gcmsg" }
read_sdc $proto_root/physical/constraints.sdc
if {[catch {set_propagated_clock [get_clocks core_clk]} pcmsg]} { puts "PROPCLK $pcmsg" }
if {[catch {detailed_placement -incremental -max_displacement {20 40}} msg]} {
  puts "INCR_FAIL $msg"
  if {[catch {detailed_placement} msg2]} { puts "DPL_FAIL $msg2" }
}
if {[catch {check_placement -verbose} cmsg]} {
  puts "PLACE $cmsg"
} else {
  puts "PLACE_OK"
}
write_db $out/swapped_legal.odb

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
global_route -congestion_iterations 50 -verbose -guide_file $out/co6a.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/co6a.drc
puts "DRT_DONE"

if {[catch {repair_antennas -iterations 3} amsg]} { puts "ANTENNA_REPAIR $amsg" }
if {[catch {check_antennas -report_file $out/antenna.rpt} amsg2]} { puts "ANTENNA_CHECK $amsg2" }
set n_ant 0
foreach inst [$block getInsts] {
  if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n_ant }
}
puts "ANTENNA_CELLS $n_ant"

# pin sides
set N 0; set W 0; set E 0; set S 0
set die [$block getDieArea]
set dx [$die xMin]; set dy [$die yMin]; set dX [$die xMax]; set dY [$die yMax]
foreach term [$block getBTerms] {
  set side "?"
  foreach pin [$term getBPins] {
    foreach box [$pin getBoxes] {
      set x1 [$box xMin]; set y1 [$box yMin]; set x2 [$box xMax]; set y2 [$box yMax]
      if {$x1 <= $dx} { set side W }
      if {$x2 >= $dX} { set side E }
      if {$y1 <= $dy} { set side S }
      if {$y2 >= $dY} { set side N }
    }
  }
  puts "BTERM [$term getName] SIDE $side"
  switch $side { N {incr N} W {incr W} E {incr E} S {incr S} }
}
puts "PIN_SIDES N=$N W=$W E=$E S=$S TOTAL=[expr {$N+$W+$E+$S}]"

write_db $out/routed.odb
write_def $out/routed.def
write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
puts "CO6A_SWAP_DONE"
exit
