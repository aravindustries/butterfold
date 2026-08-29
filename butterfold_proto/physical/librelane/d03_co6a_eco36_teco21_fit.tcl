set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco24/butterfold_top_co6a36_teco20.odb
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
foreach sz {1 2 4} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__dlyd_$sz]
  puts "dlyd_$sz w=[expr [$m getWidth]*1.0/$dbu]"
}
proc gap_right {block inst dbu} {
  set b [$inst getBBox]
  set ymin [$b yMin]; set ymax [$b yMax]; set xmax [$b xMax]
  set best 1e99
  foreach o [$block getInsts] {
    if {$o eq $inst} continue
    set ob [$o getBBox]
    if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
    if {[$ob xMin] >= $xmax && [$ob xMin] < $best} { set best [$ob xMin] }
  }
  if {$best > 1e98} { return 999 }
  return [expr {($best-$xmax)*1.0/$dbu}]
}
foreach n {input1 input2 input3 input4 input5 input6 input7 input8} {
  set i [$block findInst $n]
  set b [$i getBBox]
  puts "$n [[$i getMaster] getName] [$i getOrient] x=[expr [$b xMin]*1.0/$dbu] w=[expr ([$b xMax]-[$b xMin])*1.0/$dbu] gapR=[gap_right $block $i $dbu]"
}
exit
