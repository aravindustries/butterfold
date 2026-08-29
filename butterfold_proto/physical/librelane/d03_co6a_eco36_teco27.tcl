# teco27 from teco26: KEEP_WIRES *_1->*_2 on remaining cap/slew drivers that fit.
# Skip aoi221 and dff. Skip oai32 with shift>2.24. Recheck setup/hold/slew/cap.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco30/butterfold_top_co6a36_teco26.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco31
file mkdir $outdir
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
catch {set_thread_count 22}
set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
# name master shift_um
set swaps {
  _12601_ gf180mcu_fd_sc_mcu9t5v0__oai32_2 0.56
  _11434_ gf180mcu_fd_sc_mcu9t5v0__aoi211_2 0.56
  _12214_ gf180mcu_fd_sc_mcu9t5v0__aoi211_2 1.68
  _17231_ gf180mcu_fd_sc_mcu9t5v0__oai31_2 2.24
  _11765_ gf180mcu_fd_sc_mcu9t5v0__oai31_2 2.24
  _15762_ gf180mcu_fd_sc_mcu9t5v0__oai21_2 1.12
  _12458_ gf180mcu_fd_sc_mcu9t5v0__oai32_2 2.24
  _13042_ gf180mcu_fd_sc_mcu9t5v0__nand3_2 1.12
  _12519_ gf180mcu_fd_sc_mcu9t5v0__aoi22_2 0.00
  _12188_ gf180mcu_fd_sc_mcu9t5v0__aoi21_2 0.56
  _10236_ gf180mcu_fd_sc_mcu9t5v0__and2_2 0.00
  _09563_ gf180mcu_fd_sc_mcu9t5v0__nor3_2 1.12
  _11094_ gf180mcu_fd_sc_mcu9t5v0__oai21_2 1.12
  _11925_ gf180mcu_fd_sc_mcu9t5v0__nor3_2 1.12
  _09860_ gf180mcu_fd_sc_mcu9t5v0__nand3_2 1.12
  _12169_ gf180mcu_fd_sc_mcu9t5v0__aoi21_2 0.56
  _11559_ gf180mcu_fd_sc_mcu9t5v0__aoi21_2 0.56
  _11319_ gf180mcu_fd_sc_mcu9t5v0__aoi21_2 0.56
  _11898_ gf180mcu_fd_sc_mcu9t5v0__oai31_2 2.24
  _11739_ gf180mcu_fd_sc_mcu9t5v0__aoi22_2 0.00
  clone388 gf180mcu_fd_sc_mcu9t5v0__oai21_2 1.12
  _11461_ gf180mcu_fd_sc_mcu9t5v0__aoi21_2 0.56
  _09262_ gf180mcu_fd_sc_mcu9t5v0__clkinv_2 0.00
  _12466_ gf180mcu_fd_sc_mcu9t5v0__oai32_2 1.12
  _14265_ gf180mcu_fd_sc_mcu9t5v0__nor3_2 0.00
  _11785_ gf180mcu_fd_sc_mcu9t5v0__oai31_2 2.24
}
set nswap 0
foreach {name tgt sh} $swaps {
  set i [$block findInst $name]
  set m [$db findMaster $tgt]
  set ori [$i getOrient]
  lassign [$i getLocation] x y
  $i swapMaster $m
  $i setOrient $ori
  if {$sh > 0} {
    $i setLocation [expr {$x - int($sh*$dbu)}] $y
  } else {
    $i setLocation $x $y
  }
  $i setPlacementStatus FIRM
  incr nswap
  puts "SWAP $name $tgt shift=$sh"
}
puts "NSWAP $nswap"
foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name"; exit 1
  }
}
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -group_path_count 2 > $outdir/setup_top2.rpt
report_check_types -max_slew -max_cap -violators > $outdir/elec_liberty_violators.rpt
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
write_db $outdir/butterfold_top_co6a36_teco27.odb
puts "TECO27_DONE"
exit
