# Closed-ODB routing / antenna / orientation / netlist dump for shrink-area.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/butterfold_top_closed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]
if {[file exists $out/spef/butterfold_top.max.spef]} {
  read_spef -corner $c $out/spef/butterfold_top.max.spef
}

set db [ord::get_db]
set block [ord::get_db_block]
set tech [$db getTech]
set dbu [$tech getDbUnitsPerMicron]
set die [$block getDieArea]
set dw [expr {[$die dx] / double($dbu)}]
set dh [expr {[$die dy] / double($dbu)}]
puts [format "DIE_UM %.2f %.2f  AREA_MM2 %.6f" $dw $dh [expr {$dw * $dh / 1e6}]]

set sram 0
set diode 0
array set aoi221 {}
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} { incr sram }
  if {[string match *antenna* $mn]} { incr diode }
  if {[string match *aoi221_2 $mn]} {
    set o [$inst getOrient]
    if {![info exists aoi221($o)]} { set aoi221($o) 0 }
    incr aoi221($o)
    puts "AOI221_2 [$inst getName] $o"
  }
}
puts "SRAM_COUNT $sram"
puts "ANTENNA_DIODE_COUNT $diode"
puts "AOI221_2_ORIENT [array get aoi221]"

set unrouted 0
set signal 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  incr signal
  set w [$net getWire]
  set nterm [llength [$net getITerms]]
  set nbterm [llength [$net getBTerms]]
  if {($nterm + $nbterm) > 1 && ($w eq "NULL" || $w eq "")} {
    incr unrouted
    puts "UNROUTED [$net getName]"
  }
}
puts "SIGNAL_NETS $signal UNROUTED $unrouted"

set markers 0
if {![catch {set ms [$block getMarkers]}]} {
  set markers [llength $ms]
}
puts "DB_MARKERS $markers"

set ant [check_antennas]
puts "ANTENNA_CHECK $ant"
catch {report_disconnected_pins > $out/disconnected_pins.rpt}
puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"

write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
write_verilog $out/butterfold_top.final.v
write_cdl -include_fillers -masters "$pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/cdl/gf180mcu_fd_sc_mcu9t5v0.cdl $pdk/libs.ref/gf180mcu_fd_ip_sram/cdl/gf180mcu_fd_ip_sram__sram256x8m8wm1.cdl" $out/butterfold_top.cdl
puts "VERIFY_DONE"
