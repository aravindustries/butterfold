# Targeted setup ECO2 from clean setup2 R180 checkpoint.
# Re-apply ECO1 swaps plus the new _18691_ / clone335 class.
# remove_fillers + legalize + FULL signal GRT/DRT (setup2-proven).
# NO repair_design. Do not touch the nine aoi221_2 R180.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco2/butterfold_top_co6a36_setup2.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco6
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
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]

proc eco_swap {block db inst tgt} {
  global nine
  if {$inst in $nine} { puts "SKIP_NINE $inst"; return 0 }
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; return 0 }
  set src [[$i getMaster] getName]
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt have=$src"; return 0 }
  if {$src eq $tgt} { puts "ALREADY $inst $tgt"; return 0 }
  if {[catch {$i swapMaster $m} msg]} {
    puts "SWAP_FAIL $inst $src -> $tgt $msg"
    return 0
  }
  puts "SWAP $inst $src -> $tgt"
  return 1
}

set nswap 0
set pairs {
  fanout300 gf180mcu_fd_sc_mcu9t5v0__clkbuf_4
  fanout301 gf180mcu_fd_sc_mcu9t5v0__clkbuf_4
  clone310  gf180mcu_fd_sc_mcu9t5v0__clkbuf_4
  fanout294 gf180mcu_fd_sc_mcu9t5v0__clkbuf_4
  clone399  gf180mcu_fd_sc_mcu9t5v0__clkbuf_4
  _09419_   gf180mcu_fd_sc_mcu9t5v0__nand2_4
  _09512_   gf180mcu_fd_sc_mcu9t5v0__nand2_4
  _09513_   gf180mcu_fd_sc_mcu9t5v0__oai221_2
  _09424_   gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _09514_   gf180mcu_fd_sc_mcu9t5v0__or2_4
  _18564_   gf180mcu_fd_sc_mcu9t5v0__dffrnq_4
  max_cap217 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  _15953_   gf180mcu_fd_sc_mcu9t5v0__aoi211_2
  _15978_   gf180mcu_fd_sc_mcu9t5v0__nand2_4
  clone308  gf180mcu_fd_sc_mcu9t5v0__nor2_4
  _16440_   gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _15981_   gf180mcu_fd_sc_mcu9t5v0__nor3_4
  _18691_   gf180mcu_fd_sc_mcu9t5v0__dffrnq_4
  _09427_   gf180mcu_fd_sc_mcu9t5v0__xnor2_4
  _09445_   gf180mcu_fd_sc_mcu9t5v0__and4_4
  _09428_   gf180mcu_fd_sc_mcu9t5v0__and2_4
  _09438_   gf180mcu_fd_sc_mcu9t5v0__oai21_4
  clone335  gf180mcu_fd_sc_mcu9t5v0__oai31_4
  _15963_   gf180mcu_fd_sc_mcu9t5v0__oai221_2
  _09508_   gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _09509_   gf180mcu_fd_sc_mcu9t5v0__oai22_4
  _09499_   gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _15954_   gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _15951_   gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _15942_   gf180mcu_fd_sc_mcu9t5v0__nor2_4
  fanout298 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  max_cap98 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
}
foreach {inst tgt} $pairs {
  incr nswap [eco_swap $block $db $inst $tgt]
}
puts "TECO2_SWAPPED $nswap"

catch {remove_fillers}
puts "REMOVED_FILLERS"

foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  set n [$inst getName]
  if {$n in $nine || [string match *sram256x8m8wm1* $mn]} {
    $inst setPlacementStatus FIRM
  } else {
    $inst setPlacementStatus PLACED
  }
}
foreach name $nine {
  catch {set_dont_touch [get_cells $name]}
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {400 120}} msg]} {
  puts "LEGALIZE_WARN $msg"
  catch {detailed_placement}
}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_BAD $cmsg" } else { puts "PLACE_OK" }

foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
  $i setPlacementStatus FIRM
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
if {[catch {global_route -congestion_iterations 50 -verbose -guide_file $outdir/eco.guide} g]} {
  puts "GRT_FAIL $g"; exit 1
} else { puts "GRT_OK" }
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $outdir/eco.drc} d]} {
  puts "DRT_WARN $d"
} else { puts "DRT_OK" }

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "HOLD_WNS_MAXCORNER"; report_wns -min
puts "HOLD_TNS_MAXCORNER"; report_tns -min
catch {puts "SLEW [sta::max_slew_violation_count]"}
catch {puts "CAP [sta::max_capacitance_violation_count]"}
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -group_path_count 20 -fields {slew cap fanout net} \
  > $outdir/setup_top20.rpt

set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$inst getOrient] { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
foreach name $nine {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}
write_db $outdir/butterfold_top_co6a36_teco2.odb
write_def $outdir/butterfold_top_co6a36_teco2.def
puts "TECO2_DONE"
exit
