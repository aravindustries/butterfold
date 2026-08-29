set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco29/butterfold_top_co6a36_teco25.odb
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
foreach n {fanout293 fanout292 max_cap50 max_cap302} {
  set i [$block findInst $n]
  set b [$i getBBox]
  set xmax [$b xMax]; set xmin [$b xMin]; set ymin [$b yMin]; set ymax [$b yMax]
  set best 1e99
  foreach o [$block getInsts] {
    if {$o eq $i} continue
    set ob [$o getBBox]
    if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
    if {[$ob xMin] >= $xmax && [$ob xMin] < $best} { set best [$ob xMin] }
  }
  set gr [expr {($best-$xmax)*1.0/$dbu}]
  puts "$n [[$i getMaster] getName] w=[expr ([$b xMax]-[$b xMin])*1.0/$dbu] gapR=$gr"
}
foreach sz {2 4 8} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_$sz]
  puts "buf_$sz w=[expr [$m getWidth]*1.0/$dbu]"
}
exit
