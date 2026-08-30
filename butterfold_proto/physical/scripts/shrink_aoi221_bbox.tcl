read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/shrink_signoff/butterfold_top_closed.odb
set block [ord::get_db_block]
set tech [[ord::get_db] getTech]
set u [$tech getDbUnitsPerMicron]
set nfill 0
foreach inst [$block getInsts] {
  set n [[$inst getMaster] getName]
  if {[string match *fill_* $n] || [string match *fillcap_* $n]} { incr nfill }
}
puts "FILL_INSTS $nfill"
foreach inst [$block getInsts] {
  set n [[$inst getMaster] getName]
  if {![string match *aoi221_2 $n]} { continue }
  set b [$inst getBBox]
  set loc [$inst getLocation]
  puts [format "AOI %s orient=%s loc=%.3f,%.3f bbox=%.3f,%.3f-%.3f,%.3f status=%s" \
    [$inst getName] [$inst getOrient] \
    [expr {[lindex $loc 0]/double($u)}] [expr {[lindex $loc 1]/double($u)}] \
    [expr {[$b xMin]/double($u)}] [expr {[$b yMin]/double($u)}] \
    [expr {[$b xMax]/double($u)}] [expr {[$b yMax]/double($u)}] \
    [$inst getPlacementStatus]]
}
puts "PREFIX_SAMPLE"
set i 0
foreach inst [$block getInsts] {
  set n [$inst getName]
  if {[string match FILLER* $n] || [string match fill_* $n] || [string match FILL_* $n]} {
    puts "NAME $n master=[[$inst getMaster] getName]"
    incr i
    if {$i > 5} break
  }
}
