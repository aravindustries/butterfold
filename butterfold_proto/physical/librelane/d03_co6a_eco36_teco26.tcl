# teco26 from teco25: KEEP_WIRES fanout293 buf_2 -> buf_4, shift 1.12 um left.
# Recovers the last ~10 ps on _18287_/_18480_ after rst_n tree.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco29
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco30
file mkdir $outdir
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src/butterfold_top_co6a36_teco25.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
catch {set_thread_count 22}
set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set inst [$block findInst fanout293]
lassign [$inst getLocation] x0 y0
set ori [$inst getOrient]
puts "BEFORE [[$inst getMaster] getName] $x0 $y0 $ori"
$inst swapMaster [$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_4]
set x1 [expr {$x0 - int(1.12*$dbu)}]
$inst setOrient $ori
$inst setLocation $x1 $y0
$inst setPlacementStatus FIRM
puts "AFTER [[$inst getMaster] getName] $x1 $y0"
set bb [$inst getBBox]
puts "BBOX [expr [$bb xMin]*1.0/$dbu] [expr [$bb yMin]*1.0/$dbu] [expr [$bb xMax]*1.0/$dbu] [expr [$bb yMax]*1.0/$dbu]"
set hits 0
foreach o [$block getInsts] {
  if {$o eq $inst} continue
  set ob [$o getBBox]
  if {[$ob yMax] <= [$bb yMin] || [$ob yMin] >= [$bb yMax]} continue
  if {[$ob xMax] <= [$bb xMin] || [$ob xMin] >= [$bb xMax]} continue
  puts "OVERLAP [$o getName]"; incr hits
}
if {$hits} { puts "ABORT"; exit 1 }
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
write_db $outdir/butterfold_top_co6a36_teco26.odb
puts "TECO26_DONE"
exit
