set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco32/butterfold_top_co6a36_teco28.odb
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
foreach sz {1 2} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_$sz]
  puts "aoi221_$sz w=[expr [$m getWidth]*1.0/$dbu]"
}
foreach n {_11198_ _11447_ _11183_ _11527_ _11150_ _11164_ _11225_ _12569_ _12482_ _20030_} {
  set i [$block findInst $n]
  set b [$i getBBox]
  puts "$n [[$i getMaster] getName] [$i getOrient] w=[expr ([$b xMax]-[$b xMin])*1.0/$dbu] x=[expr [$b xMin]*1.0/$dbu] y=[expr [$b yMin]*1.0/$dbu]"
}
exit
