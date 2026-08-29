# teco16: ONE local data-path ECO from teco12.
# Common to all 6 remaining paths: rebuffer265 clkbuf_8 on net265 (FO=2, cap=0.23).
# Upsize clkbuf_8 -> clkbuf_16. No capture-clock change. No full reroute.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/butterfold_top_co6a36_teco12.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco20
file mkdir $outdir
puts "ECO_SRC $src"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]
set spef $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/after.max.spef
read_spef $spef
puts "BEFORE"; report_wns -max; report_tns -max

set inst [$block findInst rebuffer265]
puts "REBUFFER265 [[$inst getMaster] getName] orient=[$inst getOrient]"
lassign [$inst getLocation] x0 y0
puts "LOC $x0 $y0"
set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
if {[catch {$inst swapMaster $m} msg]} { puts "SWAP_FAIL $msg"; exit 1 }
puts "SWAP rebuffer265 -> clkbuf_16"

# Collect changed nets before legalize.
array set changed {}
foreach it [$inst getITerms] {
  set n [$it getNet]
  if {$n eq "NULL" || $n eq ""} continue
  if {[$n isSpecial]} continue
  set st [$n getSigType]
  if {$st eq "POWER" || $st eq "GROUND" || $st eq "CLOCK"} continue
  set changed([$n getName]) $n
}

foreach i [$block getInsts] { $i setPlacementStatus FIRM }
$inst setPlacementStatus PLACED
# Un-FIRM nearby logic only so the larger clkbuf can sit.
set win 30000
foreach i [$block getInsts] {
  if {[$i getName] in $nine} continue
  set mn [[$i getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} continue
  if {[string match *fill* $mn] || [string match *endcap* $mn] || [string match *tap* $mn]} continue
  lassign [$i getLocation] ix iy
  if {abs($ix-$x0)<$win && abs($iy-$y0)<$win} { $i setPlacementStatus PLACED }
}
set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -incremental -max_displacement {80 40}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
lassign [$inst getLocation] x1 y1
puts "NEW_LOC $x1 $y1 [[$inst getMaster] getName]"
foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
  $i setPlacementStatus FIRM
}

set nrip 0
foreach nn [array names changed] {
  set n [$block findNet $nn]
  if {$n eq "NULL"} continue
  set w [$n getWire]
  if {$w ne "" && $w ne "NULL"} { catch {odb::dbWire_destroy $w}; incr nrip }
  catch {$n clearGuides}
}
puts "RIP $nrip nets: [array names changed]"

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 20 -verbose -guide_file $outdir/eco.guide} g]} {
  puts "GRT_WARN $g"
} else { puts "GRT_OK" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $outdir/eco.drc} d]} {
  puts "DRT_WARN $d"
} else { puts "DRT_OK" }

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "HOLD_WNS_MAXCORNER"; report_wns -min
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 10 -fields {slew cap fanout net} \
  > $outdir/setup_violations.rpt
set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
write_db $outdir/butterfold_top_co6a36_teco16.odb
write_def $outdir/butterfold_top_co6a36_teco16.def
puts "TECO16_DONE"
exit
