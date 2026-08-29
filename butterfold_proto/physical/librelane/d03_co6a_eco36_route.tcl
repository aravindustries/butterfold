# Fresh pre-DRT R180 + production GRT/DRT from pad4/10.
# Abandons pgfix detailed routing. Nine aoi221_2 cells are R180 before route.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $cand/co6a36
file mkdir $eco
set odb $proto/physical/librelane/runs/d03_ach_pnr_pad4/10-openroad-resizertimingpostgrt/butterfold_top.odb

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
catch {set_thread_count 22}

set block [ord::get_db_block]
set dbu [$block getDefUnits]
set die [$block getDieArea]
set core [$block getCoreArea]
puts "START_CHECKPOINT $odb"
puts "START_STAGE 10-openroad-resizertimingpostgrt"
puts [format "DIE %.3f %.3f %.3f %.3f" \
  [expr {[$die xMin]*1.0/$dbu}] [expr {[$die yMin]*1.0/$dbu}] \
  [expr {[$die xMax]*1.0/$dbu}] [expr {[$die yMax]*1.0/$dbu}]]
puts [format "CORE %.3f %.3f %.3f %.3f" \
  [expr {[$core xMin]*1.0/$dbu}] [expr {[$core yMin]*1.0/$dbu}] \
  [expr {[$core xMax]*1.0/$dbu}] [expr {[$core yMax]*1.0/$dbu}]]
puts "BTERMS [llength [$block getBTerms]]"

set sram_xy {}
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} {
    lassign [$inst getLocation] sx sy
    puts [format "SRAM_BEFORE %s %.3f %.3f %s" [$inst getName] [expr {$sx*1.0/$dbu}] [expr {$sy*1.0/$dbu}] [$inst getOrient]]
    dict set sram_xy [$inst getName] [list $sx $sy]
  }
}

proc aoi_counts {block} {
  set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
  foreach inst [$block getInsts] {
    if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
      switch -- [$inst getOrient] {
        MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my}
      }
    }
  }
  puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
}

puts "BEFORE_ORIENT"
aoi_counts $block

set db [ord::get_db]
set m2 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_2]
if {$m2 eq "NULL" || $m2 eq ""} { puts "MISSING_AOI221_2_MASTER"; exit 1 }
puts [format "AOI221_2_SIZE %.3f x %.3f" [expr {[$m2 getWidth]*1.0/$dbu}] [expr {[$m2 getHeight]*1.0/$dbu}]]

proc snap_bbox_ll {inst x0 y0} {
  set bb [$inst getBBox]
  set dx [expr {$x0 - [$bb xMin]}]
  set dy [expr {$y0 - [$bb yMin]}]
  lassign [$inst getLocation] cx cy
  $inst setLocation [expr {$cx + $dx}] [expr {$cy + $dy}]
}

set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set core_y0 [$core yMin]
set row_h [expr {int(5.04 * $dbu)}]
catch {remove_fillers}
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} {
    $inst setPlacementStatus FIRM
  } else {
    $inst setPlacementStatus PLACED
  }
}

foreach name $insts {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "MISSING $name"; exit 1 }
  set bb [$i getBBox]
  set x0 [$bb xMin]
  set y0 [$bb yMin]
  lassign [$i getLocation] ox oy
  puts [format "BEFORE %s %s %s loc=%.3f,%.3f bbox=%.3f,%.3f-%.3f,%.3f" \
    $name [[$i getMaster] getName] [$i getOrient] \
    [expr {$ox*1.0/$dbu}] [expr {$oy*1.0/$dbu}] \
    [expr {$x0*1.0/$dbu}] [expr {$y0*1.0/$dbu}] \
    [expr {[$bb xMax]*1.0/$dbu}] [expr {[$bb yMax]*1.0/$dbu}]]
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
    # Even rows are R0/MY. R180 is rail-legal only on odd MX rows.
    set y1 [expr {$y0 - $row_h}]
    if {$y1 < $core_y0} { set y1 [expr {$y0 + $row_h}] }
    snap_bbox_ll $i [$bb xMin] $y1
    puts "ROW_SHIFT $name even_row $row -> odd"
  }
  $i setPlacementStatus FIRM
  set bb3 [$i getBBox]
  puts [format "AFTER %s %s %s loc=%.3f,%.3f bbox=%.3f,%.3f-%.3f,%.3f" \
    $name [[$i getMaster] getName] [$i getOrient] \
    [expr {[lindex [$i getLocation] 0]*1.0/$dbu}] [expr {[lindex [$i getLocation] 1]*1.0/$dbu}] \
    [expr {[$bb3 xMin]*1.0/$dbu}] [expr {[$bb3 yMin]*1.0/$dbu}] \
    [expr {[$bb3 xMax]*1.0/$dbu}] [expr {[$bb3 yMax]*1.0/$dbu}]]
}

puts "AFTER_ORIENT"
aoi_counts $block

if {[catch {check_placement -verbose} pmsg]} {
  puts "PLACE_NEEDS_LEGALIZE $pmsg"
  if {[catch {detailed_placement -max_displacement {80 6}} dmsg]} {
    puts "DPL_WARN $dmsg"
  }
  if {[catch {check_placement -verbose} pmsg2]} {
    puts "PLACE_RETRY_WIDER $pmsg2"
    if {[catch {detailed_placement -max_displacement {200 6}} dmsg2]} {
      puts "DPL2_WARN $dmsg2"
    }
  }
  if {[catch {check_placement -verbose} pmsg3]} {
    puts "PLACE_BAD $pmsg3"
    write_db $eco/butterfold_top_co6a36_placefail.odb
    exit 1
  } else {
    puts "PLACE_OK_AFTER_LEGALIZE"
  }
} else {
  puts "PLACE_OK"
}
catch {global_connect}

foreach name $insts {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    puts "MASTER_LOST $name [[$i getMaster] getName]"
    exit 1
  }
  if {[$i getOrient] ne "R180"} {
    puts "ORIENT_LOST $name [$i getOrient]"
    $i setPlacementStatus PLACED
    set bb [$i getBBox]
    set x0 [$bb xMin]; set y0 [$bb yMin]
    $i setOrient R180
    snap_bbox_ll $i $x0 $y0
  }
  $i setPlacementStatus FIRM
}

if {[catch {check_placement -verbose} pmsg4]} {
  puts "PLACE_BAD_AFTER_FIRM $pmsg4"
  exit 1
} else {
  puts "PLACE_OK_FIRM"
}

foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} {
    lassign [$inst getLocation] sx sy
    set old [dict get $sram_xy [$inst getName]]
    if {$sx != [lindex $old 0] || $sy != [lindex $old 1]} {
      puts "SRAM_MOVED [$inst getName]"
      exit 1
    }
    puts [format "SRAM_AFTER %s %.3f %.3f %s" [$inst getName] [expr {$sx*1.0/$dbu}] [expr {$sy*1.0/$dbu}] [$inst getOrient]]
  }
}

puts "FROZEN_ORIENT"
aoi_counts $block

# Fresh signal route: drop stale guides/wires, keep PDN special nets.
set n_clear 0
foreach net [$block getNets] {
  if {[$net isSpecial]} continue
  set sig [$net getSigType]
  if {$sig eq "POWER" || $sig eq "GROUND"} continue
  set w [$net getWire]
  if {$w ne "" && $w ne "NULL"} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
  incr n_clear
}
puts "CLEARED_SIGNAL_NETS $n_clear"
catch {global_connect}

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}

puts "GRT_START"
if {[catch {global_route -congestion_iterations 50 -verbose -guide_file $eco/co6a36.guide} gmsg]} {
  puts "GRT_FAIL $gmsg"
  write_db $eco/butterfold_top_co6a36_grtfail.odb
  exit 1
} else {
  puts "GRT_OK"
}

puts "DRT_START"
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/co6a36.drc} dmsg]} {
  puts "DRT_FAIL $dmsg"
} else {
  puts "DRT_OK"
}

proc count_unwired {block} {
  set unwired 0
  set signal 0
  foreach net [$block getNets] {
    if {[$net isSpecial]} continue
    set sig [$net getSigType]
    if {$sig eq "POWER" || $sig eq "GROUND"} continue
    set nterms [expr {[llength [$net getITerms]] + [llength [$net getBTerms]]}]
    if {$nterms < 2} continue
    incr signal
    set w [$net getWire]
    if {$w eq "" || $w eq "NULL"} { incr unwired }
  }
  puts "SIGNAL_NETS $signal UNWIRED $unwired"
  return $unwired
}

puts "POST_DRT"
set unwired [count_unwired $block]
puts "ANT_POST_DRT"
set ant_bad 0
if {[catch {set ant_bad [check_antennas]} amsg]} {
  puts "ANT_CHECK_ERR $amsg"
  set ant_bad 1
}
puts "ANT_CHECK $ant_bad"

# Production post-DRT antenna repair (up to 3 diode+DRT iterations).
set ant_iter 0
while {$ant_bad && $ant_iter < 3} {
  incr ant_iter
  puts "ANT_REPAIR_START $ant_iter"
  if {[catch {repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10} rmsg]} {
    puts "ANT_REPAIR_ERR $rmsg"
    break
  }
  puts "ANT_REPAIR_OK $rmsg"
  if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/co6a36_ant${ant_iter}.drc} dmsg2]} {
    puts "DRT_ANT_FAIL $dmsg2"
  } else {
    puts "DRT_ANT_OK $ant_iter"
  }
  if {[catch {set ant_bad [check_antennas]} amsg]} {
    puts "ANT_CHECK_ERR $amsg"
    set ant_bad 1
  }
  puts "ANT_AFTER_REPAIR $ant_iter check=$ant_bad"
}

puts "PLACE_FINAL"
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

puts "FINAL_ORIENT"
aoi_counts $block
foreach name $insts {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}
puts "UNWIRED_FINAL [count_unwired $block]"
puts "BTERMS_FINAL [llength [$block getBTerms]]"

write_db $eco/butterfold_top_co6a36.odb
write_def $eco/butterfold_top_co6a36.def
write_verilog -include_pwr_gnd $eco/butterfold_top.co6a36.pnl.v
puts "CO6A36_ROUTE_DONE"
exit
