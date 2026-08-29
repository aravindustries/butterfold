# Place the 5 rst_n buffers into known-empty 28/34 um gaps on row y=25.2,
# then one full signal GRT/DRT (incremental DRT is DRT-1010 on this ODB).
# Recheck extracted max-SS setup after route. teco18 remains the setup keeper.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco23
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src/butterfold_top_co6a36_teco19_preroute.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set y [expr {int(25.2*$dbu)}]
foreach {name xum} {
  teco19_rst_root 7.84
  load_slew414 47.04
  load_slew415 86.24
  load_slew416 125.44
  wire413 164.64
} {
  set i [$block findInst $name]
  $i setOrient R0
  $i setLocation [expr {int($xum*$dbu)}] $y
  $i setPlacementStatus FIRM
  set b [$i getBBox]
  puts "PLACE $name [[$i getMaster] getName] [expr [$b xMin]*1.0/$dbu] [expr [$b yMin]*1.0/$dbu] [expr [$b xMax]*1.0/$dbu] [expr [$b yMax]*1.0/$dbu]"
}
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }
foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
}

puts "REROUTE_FULL_SIGNAL"
foreach net [$block getNets] {
  if {[$net isSpecial]} continue
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} continue
  set w [$net getWire]
  if {$w ne "" && $w ne "NULL"} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 50 -verbose -guide_file $src/eco.guide} g]} {
  puts "GRT_FAIL $g"; exit 1
} else { puts "GRT_OK" }
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $src/eco.drc} d]} {
  puts "DRT_WARN $d"; exit 1
} else { puts "DRT_OK" }

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $src/after.max.spef
read_spef $src/after.max.spef
set_case_analysis 1 [get_ports rst_n]
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"
report_wns -max > $src/setup_wns.rpt
report_tns -max > $src/setup_tns.rpt
report_checks -path_delay max -group_path_count 4 > $src/setup_top4.rpt
report_check_types -max_slew -max_cap -violators > $src/elec_liberty_violators.rpt
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
write_db $src/butterfold_top_co6a36_teco19.odb
write_def $src/butterfold_top_co6a36_teco19.def
puts "TECO19_FULLROUTE_DONE"
exit
