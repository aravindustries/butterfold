# Pin/occupancy probe for _10810_ aoi22_1 -> aoi22_2 KEEP_WIRES.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco21/butterfold_top_co6a36_teco17.odb
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set inst [$block findInst _10810_]
lassign [$inst getLocation] x0 y0
set bb [$inst getBBox]
puts "INST [[$inst getMaster] getName] orient=[$inst getOrient] loc=[expr $x0*1.0/$dbu] [expr $y0*1.0/$dbu]"
puts "BBOX [expr [$bb xMin]*1.0/$dbu] [expr [$bb yMin]*1.0/$dbu] [expr [$bb xMax]*1.0/$dbu] [expr [$bb yMax]*1.0/$dbu]"
foreach it [$inst getITerms] {
  set pn [[$it getMTerm] getName]
  if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
  set n [$it getNet]
  lassign [$it getAvgXY] ok ax ay
  puts "PIN $pn avg=[expr $ax*1.0/$dbu] [expr $ay*1.0/$dbu] net=[$n getName] terms=[llength [$n getITerms]]"
}
foreach sz {1 2} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi22_$sz]
  puts "MASTER aoi22_$sz w=[expr [$m getWidth]*1.0/$dbu] h=[expr [$m getHeight]*1.0/$dbu]"
  foreach mt [$m getMTerms] {
    set pn [$mt getName]
    if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
    set xmin 1e9; set xmax -1e9; set ymin 1e9; set ymax -1e9
    foreach pin [$mt getMPins] {
      foreach box [$pin getGeometry] {
        if {[$box xMin] < $xmin} { set xmin [$box xMin] }
        if {[$box xMax] > $xmax} { set xmax [$box xMax] }
        if {[$box yMin] < $ymin} { set ymin [$box yMin] }
        if {[$box yMax] > $ymax} { set ymax [$box yMax] }
      }
    }
    puts "  $pn bbox_rel [expr $xmin*1.0/$dbu] [expr $ymin*1.0/$dbu] [expr $xmax*1.0/$dbu] [expr $ymax*1.0/$dbu]"
  }
}
# same-row 20um
set extra [expr {int(20*$dbu)}]
puts "ROW"
set items {}
foreach other [$block getInsts] {
  set ob [$other getBBox]
  if {[$ob yMax] <= [$bb yMin] || [$ob yMin] >= [$bb yMax]} continue
  if {[$ob xMax] <= [expr {[$bb xMin]-$extra}] || [$ob xMin] >= [expr {[$bb xMax]+$extra}]} continue
  lappend items [list [$ob xMin] [$other getName] [[$other getMaster] getName] [expr [$ob xMin]*1.0/$dbu] [expr [$ob xMax]*1.0/$dbu]]
}
foreach t [lsort -integer -index 0 $items] {
  puts "  [lindex $t 3]..[lindex $t 4] [lindex $t 2] [lindex $t 1]"
}
# also _10796_ in-place aoi22_2 fit
set i2 [$block findInst _10796_]
set b2 [$i2 getBBox]
puts "10796 [[$i2 getMaster] getName] [$i2 getOrient] [expr [$b2 xMin]*1.0/$dbu]..[expr [$b2 xMax]*1.0/$dbu] y=[expr [$b2 yMin]*1.0/$dbu]"
exit
