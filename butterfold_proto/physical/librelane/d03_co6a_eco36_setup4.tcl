# Full repair_design: do not dont_touch the nine aoi221_2 (that aborted repair).
# After repair, force the nine back to aoi221_2 R180.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/butterfold_top_co6a36.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco4
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
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_max_fanout 10 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set block [ord::get_db_block]
set db [ord::get_db]
set m2 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_2]
set dbu [$block getDefUnits]
set core_y0 [[$block getCoreArea] yMin]
set row_h [expr {int(5.04 * $dbu)}]

proc snap_bbox_ll {inst x0 y0} {
  set bb [$inst getBBox]
  set dx [expr {$x0 - [$bb xMin]}]
  set dy [expr {$y0 - [$bb yMin]}]
  lassign [$inst getLocation] cx cy
  $inst setLocation [expr {$cx + $dx}] [expr {$cy + $dy}]
}

foreach inst [$block getInsts] {
  if {[string match *sram256x8m8wm1* [[$inst getMaster] getName]]} {
    $inst setPlacementStatus FIRM
  }
}
foreach pat {clkbuf_*core_clk* clkbuf_*clk_regs* clkbuf_leaf_*} {
  catch {set_dont_touch [get_cells -quiet $pat]}
}

puts "PLACE_RC"
estimate_parasitics -placement
puts "REPAIR_DESIGN"
if {[catch {repair_design -slew_margin 20 -cap_margin 20} m]} {
  puts "REPAIR_DESIGN_WARN $m"
} else {
  puts "REPAIR_DESIGN_OK"
}
estimate_parasitics -placement
puts "REPAIR_TIMING"
if {[catch {repair_timing -setup -setup_margin 0.4 -repair_tns 100 -max_buffer_percent 20} m]} {
  puts "REPAIR_TIMING_WARN $m"
}
estimate_parasitics -placement
puts "AFTER_PLACEMENT"
report_wns -max
report_tns -max

puts "FORCE_NINE_R180"
foreach name $insts {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "MISSING $name"; exit 1 }
  set bb [$i getBBox]
  set x0 [$bb xMin]
  set y0 [$bb yMin]
  $i setPlacementStatus PLACED
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    if {[catch {$i swapMaster $m2} msg]} { puts "SWAP_FAIL $name $msg"; exit 1 }
  }
  $i setOrient R180
  snap_bbox_ll $i $x0 $y0
  set bb [$i getBBox]
  set y0 [$bb yMin]
  set row [expr {int(round(($y0 - $core_y0)*1.0 / $row_h))}]
  if {$row % 2 == 0} {
    set y1 [expr {$y0 - $row_h}]
    if {$y1 < $core_y0} { set y1 [expr {$y0 + $row_h}] }
    snap_bbox_ll $i [$bb xMin] $y1
  }
  $i setPlacementStatus FIRM
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}

puts "LEGALIZE"
set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -incremental -max_displacement {80 120}} m]} {
  puts "LEGALIZE_WARN $m"
  catch {detailed_placement}
}
foreach name $insts {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
  $i setPlacementStatus FIRM
}
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "INST [llength [$block getInsts]]"

puts "REROUTE"
foreach net [$block getNets] {
  if {[$net isSpecial]} continue
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} continue
  set w [$net getWire]
  if {$w ne "" && $w ne "NULL"} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 50 -verbose -guide_file $outdir/eco.guide} g]} {
  puts "GRT_FAIL $g"; exit 1
} else { puts "GRT_OK" }
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $outdir/eco.drc} d]} {
  puts "DRT_FAIL $d"
} else { puts "DRT_OK" }

set ant_bad 0
if {[catch {set ant_bad [check_antennas]}]} { set ant_bad 1 }
set i 0
while {$ant_bad && $i < 3} {
  incr i
  catch {repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10}
  catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $outdir/eco_ant${i}.drc}
  if {[catch {set ant_bad [check_antennas]}]} { set ant_bad 1 }
  puts "ANT_ITER $i check=$ant_bad"
}

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "HOLD_WNS"; report_wns -min
puts "HOLD_TNS"; report_tns -min
if {[catch {puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"}]} {
  puts "ELEC_COUNT_FAIL"
}

set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$inst getOrient] { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
foreach name $insts {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}
write_db $outdir/butterfold_top_co6a36_setup4.odb
write_def $outdir/butterfold_top_co6a36_setup4.def
puts "CO6A36_SETUP4_DONE"
exit
