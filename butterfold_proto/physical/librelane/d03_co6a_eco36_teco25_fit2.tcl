set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco29/butterfold_top_co6a36_teco25.odb
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set i [$block findInst fanout293]
lassign [$i getLocation] x y
set b [$i getBBox]
puts "loc [expr $x*1.0/$dbu] [expr $y*1.0/$dbu] ori=[$i getOrient]"
set xmin [$b xMin]; set xmax [$b xMax]; set ymin [$b yMin]; set ymax [$b yMax]
set bestL -1e99; set bestR 1e99
foreach o [$block getInsts] {
  if {$o eq $i} continue
  set ob [$o getBBox]
  if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
  if {[$ob xMax] <= $xmin && [$ob xMax] > $bestL} { set bestL [$ob xMax] }
  if {[$ob xMin] >= $xmax && [$ob xMin] < $bestR} { set bestR [$ob xMin] }
}
puts "gapL [expr {($xmin-$bestL)*1.0/$dbu}] gapR [expr {($bestR-$xmax)*1.0/$dbu}]"
puts "leftNBR [expr $bestL*1.0/$dbu] rightNBR [expr $bestR*1.0/$dbu]"
exit
