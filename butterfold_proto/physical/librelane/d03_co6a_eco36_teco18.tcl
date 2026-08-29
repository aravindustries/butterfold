# teco18 from teco17: _10810_ aoi22_1 -> aoi22_2 (NOT aoi22_4).
# Only remaining extracted violator is SRAM hi A[7] at -0.01 ns.
# FF siblings already MET. Do not full-reroute. Do not add capture skew.
# Place 2.24 um left (abut TAP) so aoi22_2 fits; A2/ZN pin boxes still overlap.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco21/butterfold_top_co6a36_teco17.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22
file mkdir $outdir
puts "ECO_SRC $src"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]

set inst [$block findInst _10810_]
lassign [$inst getLocation] x0 y0
set ori [$inst getOrient]
puts "BEFORE [[$inst getMaster] getName] orient=$ori loc_um=[expr $x0*1.0/$dbu] [expr $y0*1.0/$dbu]"
foreach it [$inst getITerms] {
  set pn [[$it getMTerm] getName]
  if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
  lassign [$it getAvgXY] ok ax ay
  puts "OLD_PIN $pn [expr $ax*1.0/$dbu] [expr $ay*1.0/$dbu] net=[[$it getNet] getName]"
}

set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi22_2]
$inst swapMaster $m
# 2.24 um = 4 sites left: xmin 507.92 abuts TAP 506.8-507.92; ur=516.88 < 518.56
set x1 [expr {$x0 - int(2.24 * $dbu)}]
$inst setOrient $ori
$inst setLocation $x1 $y0
$inst setPlacementStatus FIRM
puts "AFTER [[$inst getMaster] getName] orient=[$inst getOrient] loc_um=[expr $x1*1.0/$dbu] [expr $y0*1.0/$dbu]"

set bb [$inst getBBox]
puts "BBOX [expr [$bb xMin]*1.0/$dbu] [expr [$bb yMin]*1.0/$dbu] [expr [$bb xMax]*1.0/$dbu] [expr [$bb yMax]*1.0/$dbu]"
set hits 0
foreach other [$block getInsts] {
  if {$other eq $inst} continue
  set ob [$other getBBox]
  if {[$ob yMax] <= [$bb yMin] || [$ob yMin] >= [$bb yMax]} continue
  if {[$ob xMax] <= [$bb xMin] || [$ob xMin] >= [$bb xMax]} continue
  puts "OVERLAP [$other getName] [[$other getMaster] getName] [expr [$ob xMin]*1.0/$dbu]..[expr [$ob xMax]*1.0/$dbu]"
  incr hits
}
puts "OVERLAP_COUNT $hits"
if {$hits > 0} { puts "ABORT overlap"; exit 1 }

foreach it [$inst getITerms] {
  set pn [[$it getMTerm] getName]
  if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
  lassign [$it getAvgXY] ok ax ay
  puts "NEW_PIN $pn [expr $ax*1.0/$dbu] [expr $ay*1.0/$dbu] net=[[$it getNet] getName]"
}

foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
}

set nets {}
foreach it [$inst getITerms] {
  set n [$it getNet]
  if {$n eq "NULL" || $n eq ""} continue
  if {[$n isSpecial]} continue
  lappend nets [$n getName]
}
puts "KEEP_WIRES"
foreach nn $nets {
  set n [$block findNet $nn]
  set w [$n getWire]
  puts "PRE_EXTRACT NET $nn wire=[expr {$w eq {NULL} || $w eq {} ? {NULL} : {HASWIRE}}] terms=[llength [$n getITerms]]"
}

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 12 \
  > $outdir/setup_violations.rpt
report_checks -path_delay max -group_path_count 6 \
  > $outdir/setup_top6.rpt

puts "PATH0"
report_checks -path_delay max -group_path_count 1 -fields {slew cap fanout input_pin}
foreach ep {
  u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_sram/A[7]
  u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram/A[7]
  _18287_/D _18480_/D _18288_/D _18479_/D
} {
  puts "EP $ep"
  catch {report_checks -path_delay max -to $ep -group_path_count 1}
}

foreach nn $nets {
  set n [$block findNet $nn]
  set w [$n getWire]
  puts "POST_EXTRACT NET $nn wire=[expr {$w eq {NULL} || $w eq {} ? {NULL} : {HASWIRE}}]"
}
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
write_db $outdir/butterfold_top_co6a36_teco18.odb
write_def $outdir/butterfold_top_co6a36_teco18.def
puts "TECO18_DONE"
exit
