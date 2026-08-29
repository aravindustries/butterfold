# Proven extracted setup-ECO on the new R180-routed design.
# Nine aoi221_2 R180 cells are dont_touch + FIRM.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/butterfold_top_co6a36.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco
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
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold}
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_max_fanout 10 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set block [ord::get_db_block]
foreach name $insts {
  set i [$block findInst $name]
  $i setPlacementStatus FIRM
  if {[catch {set_dont_touch [get_cells $name]} msg]} { puts "DONT_TOUCH_CELL $name $msg" }
}
foreach inst [$block getInsts] {
  if {[string match *sram256x8m8wm1* [[$inst getMaster] getName]]} {
    $inst setPlacementStatus FIRM
  }
}
foreach pat {clkbuf_*core_clk* clkbuf_*clk_regs* clkbuf_leaf_* *u_lo.u_sram *u_hi.u_sram} {
  if {[catch {set_dont_touch [get_cells -quiet $pat]} msg]} {
    puts "DONT_TOUCH_SKIP $pat $msg"
  }
}

proc report_corner {tag} {
  global outdir
  puts "==== $tag ===="
  report_wns -max
  report_tns -max
  report_wns -min
  report_tns -min
  catch {report_wns -max > [file join $outdir ${tag}_wns_setup.rpt]}
  catch {report_tns -max > [file join $outdir ${tag}_tns_setup.rpt]}
}

puts "ECO_EXTRACT_BEFORE"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef [file join $outdir before.max.spef]
read_spef [file join $outdir before.max.spef]
report_corner before_maxss
puts "ELEC_BEFORE"
report_check_types -max_slew -max_cap -max_fanout -violators
puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"

puts "ECO_REPAIR_DESIGN"
if {[catch {repair_design -slew_margin 20 -cap_margin 20} rdmsg]} {
  puts "REPAIR_DESIGN_WARN $rdmsg"
}
estimate_parasitics -placement
puts "ECO_REPAIR_TIMING_SETUP"
if {[catch {repair_timing -setup -setup_margin 0.4 -repair_tns 100 -max_buffer_percent 20} rtmsg]} {
  puts "REPAIR_TIMING_WARN $rtmsg"
}
estimate_parasitics -placement
report_corner after_placement_repair

puts "ECO_REPAIR_RESET_VISIBLE"
if {[catch {unset_case_analysis [get_ports rst_n]} msg]} { puts "UNSET_CASE $msg" }
if {[catch {repair_design -slew_margin 20 -cap_margin 20} rdmsg2]} {
  puts "REPAIR_DESIGN_RESET_WARN $rdmsg2"
}
estimate_parasitics -placement
if {[catch {set_case_analysis 1 [get_ports rst_n]} msg]} { puts "SET_CASE $msg" }
if {[catch {repair_timing -setup -setup_margin 0.2 -repair_tns 100 -max_buffer_percent 10} rtmsg]} {
  puts "REPAIR_TIMING_RESET_WARN $rtmsg"
}
estimate_parasitics -placement
report_corner after_reset_repair

puts "ECO_LEGALIZE"
set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -incremental -max_displacement {80 120}} msg]} {
  puts "LEGALIZE_WARN $msg"
  if {[catch {detailed_placement} msg2]} { puts "LEGALIZE_FAIL $msg2" }
}
foreach name $insts {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"
    exit 1
  }
  $i setPlacementStatus FIRM
}
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }

puts "ECO_REROUTE"
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
if {[catch {global_route -congestion_iterations 50 -verbose -guide_file $outdir/eco.guide} gmsg]} {
  puts "GRT_FAIL $gmsg"; exit 1
} else { puts "GRT_OK" }
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $outdir/eco.drc} dmsg]} {
  puts "DRT_FAIL $dmsg"
} else { puts "DRT_OK" }

puts "ANT"
set ant_bad 0
if {[catch {set ant_bad [check_antennas]} amsg]} { set ant_bad 1 }
set ant_iter 0
while {$ant_bad && $ant_iter < 3} {
  incr ant_iter
  catch {repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10}
  catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $outdir/eco_ant${ant_iter}.drc}
  if {[catch {set ant_bad [check_antennas]}]} { set ant_bad 1 }
  puts "ANT_ITER $ant_iter check=$ant_bad"
}

puts "ECO_EXTRACT_AFTER_MAX"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
report_corner after_maxss
puts "ELEC_AFTER"
report_check_types -max_slew -max_cap -max_fanout -violators
puts "SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count] FANOUT [sta::max_fanout_violation_count]"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]

puts "FINAL_ORIENT"
set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$inst getOrient] { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
foreach name $insts {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}
write_db $outdir/butterfold_top_co6a36_setup.odb
write_def $outdir/butterfold_top_co6a36_setup.def
puts "CO6A36_SETUP_DONE"
exit
