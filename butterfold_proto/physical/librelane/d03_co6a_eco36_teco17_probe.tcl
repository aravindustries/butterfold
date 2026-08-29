# Probe rebuffer265 occupancy vs clkbuf_12 before ECO.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/butterfold_top_co6a36_teco12.odb
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src
set db [ord::get_db]
set block [ord::get_db_block]
set tech [ord::get_db_tech]
set dbu [$tech getDbUnitsPerMicron]
set inst [$block findInst rebuffer265]
lassign [$inst getLocation] x0 y0
set bbox [$inst getBBox]
puts "INST master=[[$inst getMaster] getName] orient=[$inst getOrient] loc_um=[expr $x0*1.0/$dbu] [expr $y0*1.0/$dbu] status=[$inst getPlacementStatus]"
puts "BBOX um ll=[expr [$bbox xMin]*1.0/$dbu] [expr [$bbox yMin]*1.0/$dbu] ur=[expr [$bbox xMax]*1.0/$dbu] [expr [$bbox yMax]*1.0/$dbu] w=[expr ([$bbox xMax]-[$bbox xMin])*1.0/$dbu]"
foreach it [$inst getITerms] {
  set mterm [$it getMTerm]
  set name [$mterm getName]
  if {$name eq "VDD" || $name eq "VSS"} continue
  lassign [$it getAvgXY] ok ax ay
  puts "  PIN $name avg_um=[expr $ax*1.0/$dbu] [expr $ay*1.0/$dbu] net=[[$it getNet] getName] avg_ok=$ok"
}
foreach sz {8 12 16} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_$sz]
  puts "MASTER clkbuf_$sz w_um=[expr [$m getWidth]*1.0/$dbu] h_um=[expr [$m getHeight]*1.0/$dbu]"
  foreach mt [$m getMTerms] {
    set pn [$mt getName]
    if {$pn eq "VDD" || $pn eq "VSS"} continue
    foreach pin [$mt getMPins] {
      foreach box [$pin getGeometry] {
        puts "  LEF $pn layer=[[$box getTechLayer] getName] [expr [$box xMin]*1.0/$dbu] [expr [$box yMin]*1.0/$dbu] [expr [$box xMax]*1.0/$dbu] [expr [$box yMax]*1.0/$dbu]"
      }
    }
  }
}
# occupancy to the right of current cell in same row
set xmax [$bbox xMax]
set xmin [$bbox xMin]
set ymin [$bbox yMin]
set ymax [$bbox yMax]
set extra [expr {int(6.72*$dbu)+200}]
set right_urx [expr {$xmax + $extra}]
set left_llx [expr {$xmin - $extra}]
puts "SCAN same-row neighbors within +/-6.72um extra"
set hits 0
foreach other [$block getInsts] {
  if {$other eq $inst} continue
  set ob [$other getBBox]
  if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
  if {[$ob xMax] <= [expr {$xmin - $extra}] || [$ob xMin] >= [expr {$xmax + $extra}]} continue
  set ox1 [expr {[$ob xMin]*1.0/$dbu}]
  set ox2 [expr {[$ob xMax]*1.0/$dbu}]
  set oy1 [expr {[$ob yMin]*1.0/$dbu}]
  set oy2 [expr {[$ob yMax]*1.0/$dbu}]
  puts "  NBR [[$other getMaster] getName] [$other getName] orient=[$other getOrient] status=[$other getPlacementStatus] bbox=$ox1 $oy1 $ox2 $oy2 gapR_um=[expr {([$ob xMin]-$xmax)*1.0/$dbu}] gapL_um=[expr {($xmin-[$ob xMax])*1.0/$dbu}]"
  incr hits
}
puts "NBR_COUNT $hits"
exit
