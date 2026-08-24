set out /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff
read_db $out/butterfold_top_elec_prelegal.odb
set t0 [clock milliseconds]
set rc [catch {detailed_placement -incremental -max_displacement {80 120}} msg]
puts "LEGAL_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"
puts "LEGAL_RC $rc"
puts "LEGAL_MSG $msg"
if {$rc} { exit 1 }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }
# restore diodes
set block [ord::get_db_block]
foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    catch {$inst setDoNotTouch 0}
    $inst setPlacementStatus PLACED
  }
}
write_db $out/butterfold_top_elec_legal.odb
write_def $out/butterfold_top_elec_legal.def
puts "WROTE_LEGAL"
