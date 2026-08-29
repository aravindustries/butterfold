# teco22 from teco21: give rst_n a real driver without ripping other nets.
# Move the existing 51 mm rst_n mesh onto rst_n_buf, drive it with buf_16
# placed in the empty y=25.2 gap, KEEP all other wires.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco26
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
set tech [ord::get_db_tech]
set dbu [$tech getDbUnitsPerMicron]
set m2 [$tech findLayer Metal2]
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_16]
set rst [$block findNet rst_n]
set mid [odb::dbNet_create $block rst_n_buf]
set w [$rst getWire]
puts "WIRE_BEFORE net=[$w getNet]"
catch {puts "DETACH [$w detach]"}
# move sinks
set sinks {}
foreach it [$rst getITerms] { lappend sinks $it }
foreach it $sinks {
  odb::dbITerm_disconnect $it
  odb::dbITerm_connect $it $mid
}
puts "RST_TERMS [llength [$rst getITerms]] MID_TERMS [llength [$mid getITerms]]"
if {[catch {$w attach $mid} msg]} { puts "ATTACH_FAIL $msg" } else { puts "ATTACH_OK" }
puts "WIRE_AFTER net=[[$w getNet] getName]"

set buf [odb::dbInst_create $block $c16 teco22_rst_root]
$buf setOrient R0
$buf setLocation [expr {int(7.84*$dbu)}] [expr {int(25.2*$dbu)}]
$buf setPlacementStatus FIRM
odb::dbITerm_connect [$buf findITerm I] $rst
odb::dbITerm_connect [$buf findITerm Z] $mid
lassign [[$buf findITerm I] getAvgXY] oki ix iy
lassign [[$buf findITerm Z] getAvgXY] okz zx zy
puts "BUF I=$ix $iy Z=$zx $zy"

# getAvgXY is in dbu; coerce to int
set ix [expr {int($ix)}]; set iy [expr {int($iy)}]
set zx [expr {int($zx)}]; set zy [expr {int($zy)}]
puts "BUF_INT I=$ix $iy Z=$zx $zy"

# port to I: pad x=0 y=273.76 -> L on Metal2
set encoder [odb::dbWireEncoder]
set wrst [odb::dbWire_create $rst]
$encoder begin $wrst
$encoder newPath $m2 ROUTED
$encoder addPoint 0 [expr {int(273.76*$dbu)}]
catch {$encoder addBTerm [$block findBTerm rst_n]}
$encoder addPoint $ix [expr {int(273.76*$dbu)}]
$encoder addPoint $ix $iy
catch {$encoder addITerm [$buf findITerm I]}
$encoder end
puts "PORT_WIRE len=[$wrst getLength]"

# Z onto the existing mesh: L from Z up to pad-height
set enc2 [odb::dbWireEncoder]
set wmid [$mid getWire]
if {$wmid eq "NULL" || $wmid eq ""} {
  set wmid [odb::dbWire_create $mid]
  $enc2 begin $wmid
} else {
  $enc2 append $wmid
}
$enc2 newPath $m2 ROUTED
$enc2 addPoint $zx $zy
catch {$enc2 addITerm [$buf findITerm Z]}
$enc2 addPoint $zx [expr {int(273.76*$dbu)}]
$enc2 end
puts "Z_WIRE done"

foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name"; exit 1
  }
}
puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -group_path_count 1 > $outdir/setup_top1.rpt
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
set_case_analysis 1 [get_ports rst_n]
report_check_types -max_slew -max_cap -violators > $outdir/elec_liberty_violators.rpt
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
write_db $outdir/butterfold_top_co6a36_teco22.odb
puts "TECO22_DONE"
exit
