set out /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff
read_db $out/butterfold_top_grt_diodes.odb
set rc [catch {detailed_placement -incremental -max_displacement {80 120}} msg]
puts "LEGAL_RC $rc $msg"
if {$rc} { exit 1 }
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK $cmsg" } else { puts "CHECK_OK" }
write_db $out/butterfold_top_grt_diodes_legal.odb
puts "WROTE_LEGAL_DIODES"
