# teco28: remaining worst oai32_1 -> oai32_2 with 3.36 um left shift.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco31/butterfold_top_co6a36_teco27.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco32
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
set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__oai32_2]
foreach {name sh} {_12553_ 3.36 _12474_ 3.36 _12577_ 3.36 _12617_ 3.36} {
  set i [$block findInst $name]
  set ori [$i getOrient]
  lassign [$i getLocation] x y
  $i swapMaster $m
  $i setOrient $ori
  $i setLocation [expr {$x - int($sh*$dbu)}] $y
  $i setPlacementStatus FIRM
  puts "SWAP $name sh=$sh ori=$ori"
}
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
report_check_types -max_slew -max_cap -violators > $outdir/elec_liberty_violators.rpt
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
write_db $outdir/butterfold_top_co6a36_teco28.odb
puts "TECO28_DONE"
exit
