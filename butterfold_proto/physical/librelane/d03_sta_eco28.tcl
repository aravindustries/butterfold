# eco28 max-SS: 9 aoi221_2 R180 dump, pins, electrical, setup.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set out $proto/physical/reports/signoff/evidence/d03_ach
file mkdir $out/drc
file mkdir $out/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a28.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $cand/co6a28.max.spef

set block [ord::get_db_block]
set dbu [$block getDefUnits]
set die [$block getDieArea]
set core [$block getCoreArea]
puts [format "DIE %.3f %.3f %.3f %.3f" \
  [expr {[$die xMin]*1.0/$dbu}] [expr {[$die yMin]*1.0/$dbu}] \
  [expr {[$die xMax]*1.0/$dbu}] [expr {[$die yMax]*1.0/$dbu}]]
puts [format "CORE %.3f %.3f %.3f %.3f" \
  [expr {[$core xMin]*1.0/$dbu}] [expr {[$core yMin]*1.0/$dbu}] \
  [expr {[$core xMax]*1.0/$dbu}] [expr {[$core yMax]*1.0/$dbu}]]

if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

set n2_mx 0; set n2_r0 0; set n2_r180 0; set n2_my 0; set n2_other 0
set n1 0; set n4 0; set nsram 0; set ninst 0
foreach inst [$block getInsts] {
  incr ninst
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} {
    incr nsram
    lassign [$inst getLocation] x y
    puts [format "SRAM %s %.3f %.3f %s" [$inst getName] [expr {$x/2000.0}] [expr {$y/2000.0}] [$inst getOrient]]
  }
  if {$mn eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_1"} { incr n1 }
  if {$mn eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_4"} { incr n4 }
  if {$mn eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    set o [$inst getOrient]
    switch -- $o {
      MX { incr n2_mx }
      R0 { incr n2_r0 }
      R180 { incr n2_r180 }
      MY { incr n2_my }
      default { incr n2_other; puts "AOI221_2_OTHER [$inst getName] $o" }
    }
  }
}
puts "INST $ninst SRAM $nsram BTERMS [llength [$block getBTerms]]"
puts "AOI221_1 $n1 AOI221_4 $n4 AOI221_2_MX $n2_mx R0 $n2_r0 R180 $n2_r180 MY $n2_my OTHER $n2_other"

set pf [open $out/drc/co6a28_pins.rpt w]
puts $pf "pin layer x0 x1 y0 y1"
foreach bt [$block getBTerms] {
  foreach pin [$bt getBPins] {
    foreach box [$pin getBoxes] {
      puts $pf [format "%-16s %-8s %.3f %.3f %.3f %.3f" [$bt getName] \
        [[$box getTechLayer] getName] \
        [expr {[$box xMin]/2000.0}] [expr {[$box xMax]/2000.0}] \
        [expr {[$box yMin]/2000.0}] [expr {[$box yMax]/2000.0}]]
      puts [format "PIN %-16s %-8s %.3f-%.3f %.3f-%.3f" [$bt getName] \
        [[$box getTechLayer] getName] \
        [expr {[$box xMin]/2000.0}] [expr {[$box xMax]/2000.0}] \
        [expr {[$box yMin]/2000.0}] [expr {[$box yMax]/2000.0}]]
    }
  }
}
close $pf

set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set cf [open $out/drc/co6a28_electrical.rpt w]
puts $cf "inst master orient x_um y_um w_um net fanout wire slew_pin"
foreach name $insts {
  set i [$block findInst $name]
  if {$i eq "NULL"} { puts $cf "MISSING $name"; continue }
  set bb [$i getBBox]
  set x [expr {[$bb xMin]*1.0/$dbu}]
  set y [expr {[$bb yMin]*1.0/$dbu}]
  set w [expr {([$bb xMax]-[$bb xMin])*1.0/$dbu}]
  set zt [$i findITerm ZN]
  set n [$zt getNet]
  set nn [expr {$n eq "NULL" ? "-" : [$n getName]}]
  set fo 0
  set haswire 0
  if {$n ne "NULL"} {
    set fo [llength [$n getITerms]]
    set wobj [$n getWire]
    if {$wobj ne "" && $wobj ne "NULL"} { set haswire 1 }
  }
  puts $cf [format "%s %s %s %.3f %.3f %.3f %s %d wire=%d" $name \
    [[$i getMaster] getName] [$i getOrient] $x $y $w $nn $fo $haswire]
  puts [format "CELL %s %s %s %.3f %.3f net=%s fanout=%d wire=%d" $name \
    [[$i getMaster] getName] [$i getOrient] $x $y $nn $fo $haswire]
}
close $cf

puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
report_wns -max > $out/setup/co6a28_setup_wns.rpt
report_tns -max > $out/setup/co6a28_setup_tns.rpt
report_checks -path_delay max -slack_max 0 -group_path_count 10 > $out/setup/co6a28_setup_violations.rpt
report_check_types -max_slew -max_cap -max_fanout -violators > $out/setup/co6a28_electrical.rpt
puts "SLEW_COUNT [sta::max_slew_violation_count]"
puts "CAP_COUNT [sta::max_capacitance_violation_count]"
puts "FANOUT_COUNT [sta::max_fanout_violation_count]"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
report_check_types -max_slew -max_capacitance -violators > $out/setup/co6a28_reset_electrical.rpt
set_case_analysis 1 [get_ports rst_n]
puts "ECO28_STA_MAX_DONE"
exit
