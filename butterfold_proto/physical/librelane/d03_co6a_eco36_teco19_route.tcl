# Route the 5 rst_n buffers from teco19 preroute. Rip only their nets.
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
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set news {teco19_rst_root wire413 load_slew414 load_slew415 load_slew416}
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]

foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }
foreach n $news {
  set i [$block findInst $n]
  $i setPlacementStatus PLACED
  lassign [$i getLocation] x y
  puts "PRELEGAL $n [[$i getMaster] getName] [expr $x*1.0/$dbu] [expr $y*1.0/$dbu]"
}
set_placement_padding -global -left 0 -right 0
if {[catch {detailed_placement -incremental -max_displacement {80 16}} msg]} {
  puts "LEGALIZE_WARN $msg"
  if {[catch {detailed_placement -incremental -max_displacement {200 40}} msg2]} {
    puts "LEGALIZE2_WARN $msg2"
  }
}
foreach n $news {
  set i [$block findInst $n]
  lassign [$i getLocation] x y
  puts "POSTLEGAL $n [[$i getMaster] getName] [expr $x*1.0/$dbu] [expr $y*1.0/$dbu] [$i getPlacementStatus]"
  $i setPlacementStatus FIRM
}
foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
}

set ripnets {}
lappend ripnets rst_n rst_n_buf
foreach bn $news {
  set i [$block findInst $bn]
  foreach it [$i getITerms] {
    set n [$it getNet]
    if {$n eq "NULL" || $n eq ""} continue
    if {[$n isSpecial]} continue
    lappend ripnets [$n getName]
  }
}
set ripnets [lsort -unique $ripnets]
puts "RIP_NETS $ripnets"
foreach nn $ripnets {
  set n [$block findNet $nn]
  if {$n eq "NULL"} continue
  set w [$n getWire]
  if {$w ne "" && $w ne "NULL"} { catch {odb::dbWire_destroy $w} }
  catch {$n clearGuides}
}

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -start_incremental} g1]} { puts "GRT_START $g1" }
if {[catch {global_route -end_incremental} g2]} { puts "GRT_END $g2" } else { puts "GRT_OK" }

if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $src/eco.drc -nets $ripnets} d]} {
  puts "DRT_NETS_WARN $d"
} else { puts "DRT_OK_NETS" }

set nulls 0
foreach nn $ripnets {
  set n [$block findNet $nn]
  if {$n eq "NULL"} continue
  set w [$n getWire]
  set st [expr {$w eq {NULL} || $w eq {} ? {NULL} : {HASWIRE}}]
  puts "NET $nn wire=$st terms=[llength [$n getITerms]]"
  if {$st eq "NULL"} { incr nulls }
}
puts "NULL_NETS $nulls"
if {$nulls > 0} { puts "ABORT unrouted nets"; exit 1 }

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
report_checks -path_delay max -group_path_count 3 > $src/setup_top3.rpt
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
puts "TECO19_ROUTE_DONE"
exit
