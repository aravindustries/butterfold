read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
report_design_area
puts "INSTANCES [llength [[ord::get_db_block] getInsts]]"
set nsram 0
set ndiode 0
foreach inst [[ord::get_db_block] getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*sram256x8*" $m]} { incr nsram }
  if {[string match "*__antenna" $m]} { incr ndiode }
}
puts "SRAM $nsram"
puts "ANTENNA_DIODES $ndiode"
puts "NETS [llength [[ord::get_db_block] getNets]]"
set die [[ord::get_db_block] getDieArea]
puts "DIE_BBOX [$die xMin] [$die yMin] [$die xMax] [$die yMax]"
puts "AREA_DONE"
