# Remove fillers, replace remaining aoi221_2 R180 (illegal-row) instances with
# aoi221_1 MX (row-legal, not the CO.6a-failing aoi221_2 MX), then refill.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
read_db $out/butterfold_top_closed.odb
set db [ord::get_db]
set block [ord::get_db_block]
set m1 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_1]
if {$m1 eq "NULL"} { error "missing aoi221_1" }

set nf 0
foreach inst [$block getInsts] {
  set n [$inst getName]
  if {[string match FILLER_* $n]} {
    odb::dbInst_destroy $inst
    incr nf
  }
}
puts "REMOVED_FILLERS $nf"

foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {![string match *aoi221_2 $mn]} { continue }
  puts "AOI_BEFORE [$inst getName] $mn [$inst getOrient]"
  if {[$inst getOrient] eq "R180" || [$inst getOrient] eq "MX"} {
    $inst setPlacementStatus PLACED
    $inst swapMaster $m1
    $inst setOrient MX
    puts "AOI_SWAP [$inst getName] -> aoi221_1 MX"
  } else {
    $inst setPlacementStatus PLACED
  }
}

set_placement_padding -global -left 1 -right 1
detailed_placement -max_displacement {200 50}
if {[catch {check_placement -verbose} m]} { puts "PLACE1 $m"; exit 1 }

foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *aoi221_2 $mn] || [string match *aoi221_1 $mn]} {
    if {[string match *aoi221* $mn]} {
      # only print the four original names if present
    }
  }
}
foreach name {_10665_ _11447_ _11500_ _11539_} {
  set inst [$block findInst $name]
  if {$inst ne "NULL"} {
    puts "AOI_AFTER $name [[$inst getMaster] getName] [$inst getOrient]"
    if {[string match *aoi221_2* [[$inst getMaster] getName]] && [$inst getOrient] eq "MX"} {
      error "aoi221_2 MX reappeared"
    }
  }
}

add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
set_thread_count 16
global_route -congestion_iterations 50 -verbose
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
catch {detailed_placement -max_displacement {500 100}}
file mkdir $out/drt
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/swap.drc
set ant [check_antennas]
puts "ANT $ant"
if {$ant} {
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
  catch {detailed_placement -max_displacement {500 100}}
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/swap2.drc
  set ant [check_antennas]
  puts "ANT2 $ant"
}

set fills {}
set decaps {}
foreach lib [$db getLibs] {
  foreach m [$lib getMasters] {
    set n [$m getName]
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
  }
}
set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
filler_placement $fill_list
global_connect
if {[catch {check_placement -verbose} m]} { puts "PLACE2 $m"; exit 1 }
foreach name {_10665_ _11447_ _11500_ _11539_} {
  set inst [$block findInst $name]
  if {$inst ne "NULL"} {
    puts "AOI_FINAL $name [[$inst getMaster] getName] [$inst getOrient]"
    if {[string match *aoi221_2* [[$inst getMaster] getName]] && [$inst getOrient] eq "MX"} {
      error "aoi221_2 MX reappeared after fill"
    }
  }
}
set ant [check_antennas]
puts "ANTENNA_FINAL $ant"
puts "INST [llength [$block getInsts]]"
write_db $out/butterfold_top_closed.odb
write_def $out/butterfold_top_closed.def
write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
puts "AOI_SWAP_FILL_DONE"
