set out /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff
read_db $out/r2_prelegal.odb
set rc [catch {detailed_placement -incremental -max_displacement {80 120}} msg]
puts "LEGAL_RC $rc $msg"
if {$rc} { exit 1 }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK $cmsg" } else { puts "CHECK_OK" }
set block [ord::get_db_block]
foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    catch {$inst setDoNotTouch 0}
    $inst setPlacementStatus PLACED
  }
}
write_db $out/r2_legal.odb
puts WROTE_LEGAL
