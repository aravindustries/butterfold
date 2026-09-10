set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set src $proto/physical/results/native_power_ring_ach/predrt/applied_m3cut_stitched.odb
if {[info exists ::env(VALIDATE_ODB)] && $::env(VALIDATE_ODB) ne ""} { set src $::env(VALIDATE_ODB) }
read_db $src
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "BTERMS [llength [[ord::get_db_block] getBTerms]]"
set u 0
foreach net [[ord::get_db_block] getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w eq "NULL" || $w eq ""} { incr u; puts "UNROUTED [$net getName]" }
}
puts "UNROUTED_SIGNAL $u"
if {[catch {check_placement -verbose} m]} { puts "PLACE_FAIL $m" } else { puts "PLACE_OK" }
set ant [check_antennas]
puts "ANT $ant"
if {$ant} {
  catch {check_antennas -verbose -report_file $proto/physical/results/native_power_ring_ach/predrt/stitched_ant.rpt}
}
puts "VALIDATE_DONE"
exit
