# Legal-orientation policy: aoi221_2 MX is the known CO.6a-failing orientation.
# Convert MX -> R180 (same flipped-row family) and FIRM so DPL cannot restore MX.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
read_db $out/butterfold_top_closed.odb
set db [ord::get_db]
set block [ord::get_db_block]

proc firm_aoi221 {} {
  set nfix 0
  foreach inst [[ord::get_db_block] getInsts] {
    set mn [[$inst getMaster] getName]
    if {![string match *aoi221_2 $mn]} { continue }
    set o [$inst getOrient]
    if {$o eq "MX"} {
      $inst setOrient R180
      incr nfix
      puts "AOI221_2_FIX [$inst getName] MX -> R180"
    }
    $inst setPlacementStatus FIRM
    puts "AOI221_2_NOW [$inst getName] [$inst getOrient] FIRM"
  }
  return $nfix
}

set nfix [firm_aoi221]
puts "AOI221_2_FIXED $nfix"

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
firm_aoi221
file mkdir $out/drt
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/aoi.drc
set ant [check_antennas]
puts "ANT $ant"
if {$ant} {
  repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10
  firm_aoi221
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/aoi2.drc
  set ant [check_antennas]
  puts "ANT2 $ant"
}
firm_aoi221
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *aoi221_2 $mn]} {
    puts "AOI221_2_FINAL [$inst getName] [$inst getOrient]"
    if {[$inst getOrient] eq "MX"} { error "aoi221_2 still MX after FIRM policy" }
  }
}
write_db $out/butterfold_top_closed.odb
write_def $out/butterfold_top_closed.def
puts "AOI221_FIX_DONE"
